/* eslint-disable no-console */
const path = require('node:path');
const express = require('express');
const helmet = require('helmet');
const http = require('node:http');
const { Server } = require('socket.io');

const app = express();
const server = http.createServer(app);
const port = Number.parseInt(process.env.PORT || '3000', 10);
const maxMessageLength = Number.parseInt(process.env.MAX_MESSAGE_LENGTH || '2000', 10);
const maxUsernameLength = 20;
const allowedOrigins = (process.env.ALLOWED_ORIGINS || '')
  .split(',')
  .map((origin) => origin.trim())
  .filter(Boolean);

const originIsAllowed = (origin) => !origin || allowedOrigins.includes(origin);

app.disable('x-powered-by');
app.use(helmet({ contentSecurityPolicy: false }));
app.use(express.static(path.join(__dirname, 'public'), { index: 'index.html' }));

const io = new Server(server, {
  cors: allowedOrigins.length > 0 ? {
    origin: (origin, callback) => {
      if (originIsAllowed(origin)) return callback(null, true);
      return callback(new Error('Origin not allowed'));
    },
    methods: ['GET'],
  } : false,
  maxHttpBufferSize: 1e5,
});

const users = new Map();
const messageTimes = new WeakMap();
const typingTimes = new WeakMap();

const cleanText = (value, maxLength) => (typeof value === 'string' ? value.trim().slice(0, maxLength) : '');
const isRateLimited = (socket, store, intervalMs) => {
  const now = Date.now();
  const previous = store.get(socket) || 0;
  if (now - previous < intervalMs) return true;
  store.set(socket, now);
  return false;
};

io.on('connection', (socket) => {
  console.log(`Socket connected: ${socket.id}. Total connected: ${io.engine.clientsCount}`);

  socket.on('new-user', (rawUsername) => {
    const username = cleanText(rawUsername, maxUsernameLength);
    if (!username || username.length < 1) return;
    users.set(socket.id, username);
    io.emit('broadcast', `Online: ${io.engine.clientsCount}`);
    socket.broadcast.emit('user-connected', username);
  });

  socket.on('new-message', (rawMessage) => {
    if (isRateLimited(socket, messageTimes, 250)) return;
    const message = cleanText(
      typeof rawMessage === 'object' && rawMessage !== null ? rawMessage.message : rawMessage,
      maxMessageLength,
    );
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

server.listen(port, '0.0.0.0', () => {
  console.log(`Server listening on port ${port}`);
});

module.exports = { app, server, io };
