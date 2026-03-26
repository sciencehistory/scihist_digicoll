import domready from 'domready';

domready(function() {
  // enter in question textarea submits

  const textarea = document.querySelector('*[data-ai-conversation-q]');
  textarea?.addEventListener('keydown', (e) => {
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

  // Pretty cheesy homegrown way to update teh section of AI answer that needs to be
  // updated as AI answer progresses. We should probably replace with turbo-stream
  // and push and true incremental updates at some point -- how soon depends on how
  // soon we need better features like incremental updates.
  function scheduleConversationFrameFetch() {
    const conversationFrame = document.querySelector('*[data-ai-conversation-frame]');

    if (conversationFrame) {
      const refreshUrl = conversationFrame.dataset.refreshUrl;
      const complete = (conversationFrame.dataset.complete === "true");
      const oldLastModifiedHeader = conversationFrame.dataset.lastModified;
      const oldLastModifiedDate = oldLastModifiedHeader && new Date(oldLastModifiedHeader);
      let delay = conversationFrame.dataset.pollMs;
      delay = (delay && Number(delay));


      //console.log(`found data-ai-conversation-frame, with poll at ${delay}`)

      if (! complete) {
        setTimeout(async function() {
          console.log("data-ai-conversation-frame polling")

          const response = await fetch(refreshUrl);
          const body = await response.text();
          const newLastModifiedValue = response.headers.get('Last-Modified');
          const newLastModifiedDate = newLastModifiedValue && new Date(newLastModifiedValue);

          const changed = newLastModifiedDate.getTime() != oldLastModifiedDate.getTime();

          console.log(`data-ai-conversation-frame received, change? ${changed}`)

          if (!response.ok) {
            throw new Error(`HTTP error: ${refreshUrl}: ${response.status}: ${body}`);
          }

          // if last modified hasn't changed, no need to update dom.
          if (changed) {
            conversationFrame.outerHTML = body;
          }

          // And do it again if not yet complete, waiting to poll again
          scheduleConversationFrameFetch();
        }, delay);
      }
    }
  }
  scheduleConversationFrameFetch();



});

