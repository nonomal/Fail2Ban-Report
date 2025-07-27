document.addEventListener('DOMContentLoaded', () => {
  const tbody = document.querySelector('#resultTable tbody');
  tbody.addEventListener('click', e => {
    if (e.target.classList.contains('action-btn')) {
      const ip = e.target.dataset.ip;
      console.log('Ban IP:', ip);
      // Hier z.B. AJAX-Call zum Ban
    }
  });
});
