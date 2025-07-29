/**
 * Shows a toast-style notification in the page.
 *
 * @param {string} message - The text to show in the notification.
 * @param {boolean} isError - Whether this is an error (red) or success/info (green).
 */
function showNotification(message, isError = false) {
  const container = document.getElementById('notification-container');
  if (!container) return;

  const note = document.createElement('div');
  note.className = 'notification';
  note.style.backgroundColor = isError ? '#722' : '#a8d5ba';  // red for errors, soft green for success
  note.style.color = isError ? '#f8f8f8' : '#2e4d32';          // light text on red, dark text on green
  note.style.padding = '0.5em 1em';
  note.style.marginBottom = '0.5em';
  note.style.borderRadius = '4px';
  note.style.boxShadow = '0 2px 4px rgba(0,0,0,0.2)';
  note.style.fontSize = '0.95em';

  note.innerText = message;
  container.appendChild(note);

  // Remove notification after 5 seconds
  setTimeout(() => {
    note.remove();
  }, 5000);
}
