document.addEventListener('DOMContentLoaded', () => {
  document.getElementById('chat').hidden = true;

  document.querySelectorAll('.navbar-burger').forEach((burger) => {
    burger.addEventListener('click', () => {
      const target = document.getElementById(burger.dataset.target);
      if (!target) return;
      burger.classList.toggle('is-active');
      target.classList.toggle('is-active');
      burger.setAttribute('aria-expanded', burger.classList.contains('is-active'));
    });
  });

  const emojiButton = document.getElementById('emoji-button');
  const messageInput = document.getElementById('message-input');
  if (emojiButton && typeof EmojiButton !== 'undefined') {
    const picker = new EmojiButton({ theme: 'dark', autoHide: false, position: 'auto-start' });
    picker.on('emoji', (emoji) => {
      messageInput.value += emoji;
      messageInput.focus();
    });
    emojiButton.addEventListener('click', () => picker.togglePicker(emojiButton));
  }

  document.getElementById('theme-button').addEventListener('click', () => {
    document.body.classList.toggle('dark');
  });

  const audioPlayer = document.getElementById('notification-sound');
  const soundControl = document.getElementById('sound-control');
  soundControl.addEventListener('change', () => {
    audioPlayer.muted = !soundControl.checked;
  });

  messageInput.addEventListener('keydown', (event) => {
    if (event.key === 'Enter') document.getElementById('send-message').click();
  });

  document.getElementById('username-input').addEventListener('keydown', (event) => {
    if (event.key === 'Enter') document.getElementById('send-username').click();
  });
});
