document.querySelector('#resultTable tbody').addEventListener('click', e => {
  if(e.target.classList.contains('action-btn')) {
    const ip = e.target.dataset.ip;
    console.log('Ban IP:', ip);
    // Hier AJAX-Call oder andere Logik
  }
});
