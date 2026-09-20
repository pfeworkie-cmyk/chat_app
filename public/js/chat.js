/* global io */

const socket = io();
const messageInput = document.getElementById('message-input');
const sendMessageButton = document.getElementById('send-message');
const notificationSound = document.getElementById('notification-sound');
const usernameInput = document.getElementById('username-input');
const sendUsernameButton = document.getElementById('send-username');
const displayMessage = document.getElementById('display-message');
const typingLabel = document.getElementById('typing-label');
const chatWindow = document.getElementById('chat-window');
const usersCounter = document.getElementById('users-counter');
const messageError = document.getElementById('message-error');
const usernameError = document.getElementById('username-error');
const joinedMessage = document.getElementById('you-joined');
const chat = document.getElementById('chat');
const login = document.getElementById('login-page');

const scrollToBottom = () => {
  chatWindow.scrollTop = chatWindow.scrollHeight;
};

const playNotification = () => {
  const playback = notificationSound.play();
  if (playback && typeof playback.catch === 'function') playback.catch(() => {});
};

const addSystemMessage = (text) => {
  const paragraph = document.createElement('p');
  paragraph.textContent = text;
  displayMessage.appendChild(paragraph);
  scrollToBottom();
};

const addChatMessage = (username, text) => {
  const paragraph = document.createElement('p');
  const name = document.createElement('strong');
  const timestamp = document.createElement('em');
  name.textContent = username;
  timestamp.textContent = ` at ${new Date().toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })}`;
  paragraph.append(name, timestamp, document.createTextNode(` : ${text}`));
  displayMessage.appendChild(paragraph);
  scrollToBottom();
};

sendUsernameButton.addEventListener('click', () => {
  const username = usernameInput.value.trim();
  if (!username) {
    usernameError.textContent = 'Name is required.';
    usernameInput.focus();
    return;
  }

  usernameError.textContent = '';
  usernameInput.value = username;
  login.style.display = 'none';
  chat.style.display = 'block';
  joinedMessage.textContent = 'You have joined the chat!';
  socket.emit('new-user', username);
  messageInput.focus();
});

sendMessageButton.addEventListener('click', () => {
  const message = messageInput.value.trim();
  if (!message) {
    messageError.textContent = 'Message is required.';
    messageInput.focus();
    return;
  }

  socket.emit('new-message', message);
  messageInput.value = '';
  messageError.textContent = '';
});

messageInput.addEventListener('input', () => {
  if (messageInput.value.trim()) messageError.textContent = '';
  socket.emit('is-typing');
});

socket.on('user-connected', (username) => {
  addSystemMessage(`${username} has connected!`);
  playNotification();
});

socket.on('broadcast', (count) => {
  usersCounter.textContent = count;
});

socket.on('new-message', (data) => {
  typingLabel.textContent = '';
  if (data && typeof data.username === 'string' && typeof data.message === 'string') {
    addChatMessage(data.username, data.message);
    playNotification();
  }
});

socket.on('is-typing', (username) => {
  typingLabel.textContent = `${username} is typing...`;
  scrollToBottom();
});

socket.on('user-disconnected', (username) => {
  addSystemMessage(username ? `${username} has disconnected!` : 'Unlogged user has disconnected!');
  if (username) playNotification();
});

socket.on('connect_error', () => {
  usernameError.textContent = 'Unable to connect to the chat server. Please try again.';
});

socket.on('connect', () => {
  if (login.style.display !== 'none') usernameError.textContent = '';
});
