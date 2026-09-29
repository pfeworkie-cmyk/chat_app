const path = require('node:path');
const express = require('express');
const helmet = require('helmet');
const http = require('node:http');
const { Server } = require('socket.io');

const DEFAULT_PORT = 3000;
const DEFAULT_MAX_MESSAGE_LENGTH = 2000;
const MAX_ALLOWED_MESSAGE_LENGTH = 10000;
const DEFAULT_MAX_CONNECTIONS = 1000;
const MAX_ALLOWED_CONNECTIONS = 10000;
const MAX_USERNAME_LENGTH = 20;

function parsePositiveInteger(value, fallback, maximum) {
  if (typeof value !== 'string' && typeof value !== 'number') return fallback;
  if (typeof value === 'string' && !/^\d+$/.test(value.trim())) return fallback;
  const parsed = Number(value);
  if (!Number.isSafeInteger(parsed) || parsed <= 0) return fallback;
  return Math.min(parsed, maximum);
}

function normalizeOrigin(origin) {
  if (typeof origin !== 'string' || !origin) return null;
  try {
    const parsed = new URL(origin);
    if (!['http:', 'https:'].includes(parsed.protocol) || parsed.origin !== origin) return null;
    return parsed.origin;
  } catch {
    return null;
  }
}

function isOriginAllowed(origin, requestHost, allowedOrigins = []) {
  if (!origin) return true;
  const normalizedOrigin = normalizeOrigin(origin);
  if (!normalizedOrigin) return false;
  if (allowedOrigins.length > 0) return allowedOrigins.includes(normalizedOrigin);
  try {
    return new URL(normalizedOrigin).host.toLowerCase() === String(requestHost || '').toLowerCase();
  } catch {
    return false;
  }
}

function cleanText(value, maxLength) {
  return typeof value === 'string' ? value.trim().slice(0, maxLength) : '';
}

function isRateLimited(socket, store, intervalMs) {
  const now = Date.now();
  const previous = store.get(socket) || 0;
  if (now - previous < intervalMs) return true;
  store.set(socket, now);
  return false;
}

function createChatServer(options = {}) {
  const configuredOrigins = options.allowedOrigins
    || (process.env.ALLOWED_ORIGINS || '').split(',').map((origin) => origin.trim()).filter(Boolean);
  const allowedOrigins = configuredOrigins.map((origin) => {
    const normalized = normalizeOrigin(origin);
    if (!normalized) throw new Error(`Invalid origin in ALLOWED_ORIGINS: ${origin}`);
    return normalized;
  });
  const maxMessageLength = parsePositiveInteger(
    options.maxMessageLength ?? process.env.MAX_MESSAGE_LENGTH,
    DEFAULT_MAX_MESSAGE_LENGTH,
    MAX_ALLOWED_MESSAGE_LENGTH,
  );
  const maxConnections = parsePositiveInteger(
    options.maxConnections ?? process.env.MAX_CONNECTIONS,
    DEFAULT_MAX_CONNECTIONS,
    MAX_ALLOWED_CONNECTIONS,
  );

  const app = express();
  const server = http.createServer(app);
  const productionCsp = process.env.NODE_ENV === 'production';
  const cspDirectives = {
    defaultSrc: ["'self'"],
    baseUri: ["'self'"],
    connectSrc: ["'self'", 'ws:', 'wss:'],
    fontSrc: ["'self'", 'data:'],
    formAction: ["'self'"],
    frameAncestors: ["'none'"],
    imgSrc: ["'self'", 'data:'],
    objectSrc: ["'none'"],
    scriptSrc: ["'self'", 'https://cdn.jsdelivr.net'],
    styleSrc: ["'self'", 'https://cdn.jsdelivr.net', "'unsafe-inline'"],
  };
  if (productionCsp) cspDirectives.upgradeInsecureRequests = [];

  app.disable('x-powered-by');
  app.use(helmet({ contentSecurityPolicy: { directives: cspDirectives } }));
  app.use(express.static(path.join(__dirname, 'public'), { index: 'index.html' }));

  const io = new Server(server, {
    cors: allowedOrigins.length > 0 ? {
      origin: (origin, callback) => callback(
        null,
        !origin || isOriginAllowed(origin, undefined, allowedOrigins),
      ),
      methods: ['GET'],
    } : false,
    allowRequest: (request, callback) => {
      const underConnectionLimit = io.engine.clientsCount < maxConnections;
      callback(null, underConnectionLimit
        && isOriginAllowed(request.headers.origin, request.headers.host, allowedOrigins));
    },
    maxHttpBufferSize: 100 * 1024,
  });

  const users = new Map();
  const messageTimes = new WeakMap();
  const typingTimes = new WeakMap();

  io.on('connection', (socket) => {
    socket.on('new-user', (rawUsername) => {
      const username = cleanText(rawUsername, MAX_USERNAME_LENGTH);
      if (!username) return;
      users.set(socket.id, username);
      io.emit('broadcast', `Online: ${io.engine.clientsCount}`);
      socket.broadcast.emit('user-connected', username);
    });

    socket.on('new-message', (rawMessage) => {
      if (isRateLimited(socket, messageTimes, 250)) return;
      const candidate = typeof rawMessage === 'object' && rawMessage !== null
        ? rawMessage.message
        : rawMessage;
      const message = cleanText(candidate, maxMessageLength);
      const username = users.get(socket.id);
      if (!username || !message) return;
      io.emit('new-message', { username, message });
    });

    socket.on('is-typing', () => {
      if (isRateLimited(socket, typingTimes, 500)) return;
      const username = users.get(socket.id);
      if (username) socket.broadcast.emit('is-typing', username);
    });

    socket.on('disconnect', () => {
      const username = users.get(socket.id);
      users.delete(socket.id);
      io.emit('broadcast', `Online: ${io.engine.clientsCount}`);
      if (username) socket.broadcast.emit('user-disconnected', username);
    });
  });

  return { app, server, io };
}

if (require.main === module) {
  const port = parsePositiveInteger(process.env.PORT, DEFAULT_PORT, 65535);
  const { server } = createChatServer();
  server.listen(port, '0.0.0.0', () => {
    console.log(`Server listening on port ${port}`);
  });
}

module.exports = {
  cleanText,
  createChatServer,
  isOriginAllowed,
  isRateLimited,
  normalizeOrigin,
  parsePositiveInteger,
};
