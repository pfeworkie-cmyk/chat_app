/* eslint-disable no-console */
/* eslint-disable import/no-unresolved */
const path = require('path');
const express = require('express');

const app = express();
const server = require('http').Server(app);
const socket = require('socket.io');

const io = socket(server, {
  cors: {
    origin: '*', // Allow all origins for development. Restrict in production.
    methods: ['GET', 'POST'],
  },
});

const PID = process.pid;
const PORT = process.env.PORT || 3000;
const users = {};

app.use(express.static(path.join(__dirname, 'public')));

// eslint-disable-next-line no-shadow
io.on('connection', (socket) => {
  console.log(`The socket is connected! Socket id: ${socket.id}. Total connected: ${io.engine.clientsCount}`);

  socket.on('new-user', (username) => {
    io.emit('broadcast', `Online: ${io.engine.clientsCount}`);
    users[socket.id] = username;
    socket.broadcast.emit('user-connected', username);
  });

  socket.on('new-message', (data) => {
    io.emit('new-message', data);
  });

  socket.on('is-typing', (username) => {
    socket.broadcast.emit('is-typing', username);
  });

  socket.on('disconnect', () => {
    io.emit('broadcast', `Online: ${io.engine.clientsCount}`);
    socket.broadcast.emit('user-disconnected', users[socket.id]);
    delete users[socket.id];
  });
});

server.listen(PORT, () => {
  console.log(`The server is Listening on http://localhost:${PORT} \nPID: ${PID}\n`);
});
