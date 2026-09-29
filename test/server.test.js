const assert = require('node:assert/strict');
const { once } = require('node:events');
const test = require('node:test');
const { io: connect } = require('socket.io-client');
const {
  cleanText,
  createChatServer,
  isOriginAllowed,
  isRateLimited,
  normalizeOrigin,
  parsePositiveInteger,
} = require('../server');

test('cleanText accepts only strings, trims whitespace, and enforces the maximum length', () => {
  assert.equal(cleanText('  hello  ', 10), 'hello');
  assert.equal(cleanText('abcdef', 3), 'abc');
  assert.equal(cleanText({ message: 'hello' }, 10), '');
});

test('positive integer settings fall back safely and are capped', () => {
  assert.equal(parsePositiveInteger(undefined, 2000, 10000), 2000);
  assert.equal(parsePositiveInteger('-1', 2000, 10000), 2000);
  assert.equal(parsePositiveInteger('90000', 2000, 10000), 10000);
  assert.equal(parsePositiveInteger('512', 2000, 10000), 512);
});

test('origin validation allows same-host and explicitly configured origins only', () => {
  assert.equal(normalizeOrigin('https://chat.example.com'), 'https://chat.example.com');
  assert.equal(normalizeOrigin('javascript:alert(1)'), null);
  assert.equal(isOriginAllowed(undefined, 'chat.example.com'), true);
  assert.equal(isOriginAllowed('https://chat.example.com', 'chat.example.com'), true);
  assert.equal(isOriginAllowed('https://evil.example', 'chat.example.com'), false);
  assert.equal(isOriginAllowed('https://frontend.example', 'chat.example.com', ['https://frontend.example']), true);
  assert.equal(isOriginAllowed('https://evil.example', 'chat.example.com', ['https://frontend.example']), false);
});

test('rate limiting tracks each socket independently', () => {
  const limiter = new WeakMap();
  const firstSocket = {};
  const secondSocket = {};
  assert.equal(isRateLimited(firstSocket, limiter, 1000), false);
  assert.equal(isRateLimited(firstSocket, limiter, 1000), true);
  assert.equal(isRateLimited(secondSocket, limiter, 1000), false);
});

test('HTTP app serves the client with CSP and no Express fingerprint header', async (t) => {
  const { server, io } = createChatServer({ allowedOrigins: [] });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  t.after(() => new Promise((resolve) => io.close(resolve)));

  const address = server.address();
  const response = await fetch(`http://127.0.0.1:${address.port}/`);
  const html = await response.text();
  assert.equal(response.status, 200);
  assert.match(html, /Artichoke Chat/);
  assert.match(html, /integrity="sha384-/);
  const contentSecurityPolicy = response.headers.get('content-security-policy');
  assert.match(contentSecurityPolicy, /default-src 'self'/);
  assert.match(contentSecurityPolicy, /script-src 'self' https:\/\/cdn\.jsdelivr\.net/);
  assert.doesNotMatch(contentSecurityPolicy, /script-src[^;]*'unsafe-inline'/);
  assert.equal(response.headers.get('x-powered-by'), null);
  const obsoleteServerScript = await fetch(`http://127.0.0.1:${address.port}/js/server.js`);
  assert.equal(obsoleteServerScript.status, 404);
});

test('Socket.IO accepts same-origin chat and rejects a foreign browser origin', async (t) => {
  const { server, io } = createChatServer({ allowedOrigins: [] });
  await new Promise((resolve, reject) => {
    server.once('error', reject);
    server.listen(0, '127.0.0.1', resolve);
  });
  const address = server.address();
  const url = `http://127.0.0.1:${address.port}`;
  const client = connect(url, {
    transports: ['websocket'],
    extraHeaders: { Origin: url },
    reconnection: false,
  });
  const foreignClient = connect(url, {
    transports: ['websocket'],
    extraHeaders: { Origin: 'https://evil.example' },
    reconnection: false,
  });

  t.after(() => {
    client.disconnect();
    foreignClient.disconnect();
    return new Promise((resolve) => io.close(resolve));
  });

  const originDeniedPromise = new Promise((resolve, reject) => {
    const timer = setTimeout(() => reject(new Error('Foreign origin was not rejected')), 2000);
    foreignClient.once('connect_error', (error) => {
      clearTimeout(timer);
      resolve(error);
    });
    foreignClient.once('connect', () => {
      clearTimeout(timer);
      reject(new Error('Foreign origin unexpectedly connected'));
    });
  });

  await once(client, 'connect');
  const messageReceived = once(client, 'new-message');
  client.emit('new-user', 'Alice');
  client.emit('new-message', { message: '<script>alert(1)</script>' });
  const [message] = await messageReceived;
  assert.deepEqual(message, { username: 'Alice', message: '<script>alert(1)</script>' });

  const originDenied = await originDeniedPromise;
  assert.ok(originDenied instanceof Error);
});
