import domready from 'domready';

domready(function() {
  // enter in question textarea submits

  const textarea = document.querySelector('*[data-ai-conversation-q]');
  textarea.addEventListener('keydown', (e) => {
    // Check if Enter was pressed without Shift (Shift+Enter usually creates a new line)
    if (e.key === 'Enter' && !e.shiftKey) {
      e.preventDefault(); // Prevents adding a new line
      textarea.form.requestSubmit(); // Submits the form
    }
  });

  // citation quote show
  document.body.addEventListener('click', function (e) {
    if (e.target.matches('[data-scihist-citation-quote-show=true]')) {
      e.preventDefault();

      const container = e.target.closest("[data-scihist-citation-quote-container=true]");

      container.querySelector("[data-scihist-citation-quote-truncated=true]").style.display = "none";
      container.querySelector("[data-scihist-citation-quote-full=true]").style.display = "";
    }
  });
});

