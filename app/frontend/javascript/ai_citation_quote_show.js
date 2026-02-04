import domready from 'domready';

domready(function() {
  document.body.addEventListener('click', function (e) {
    if (e.target.matches('[data-scihist-citation-quote-show=true]')) {
      e.preventDefault();

      const container = e.target.closest("[data-scihist-citation-quote-container=true]");

      container.querySelector("[data-scihist-citation-quote-truncated=true]").style.display = "none";
      container.querySelector("[data-scihist-citation-quote-full=true]").style.display = "";
    }
  });
});
