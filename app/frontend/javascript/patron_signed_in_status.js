// Show patron account vs sign-in links from the patron_signed_in flag cookie, so page HTML can be
// the same for everyone. See config/initializers/patron_signed_in_cookie.rb
if (document.cookie.split("; ").includes("patron_signed_in=1")) {
  document.querySelectorAll("[data-patron-signed-in-show]").forEach((el) => { el.hidden = false; });
  document.querySelectorAll("[data-patron-signed-out-show]").forEach((el) => { el.hidden = true; });
} else if (!location.pathname.startsWith("/oral_history_session")) {
  // sign-in returns to this page; added here so the HTML stays the same on every page
  document.querySelectorAll("[data-patron-signed-out-show]").forEach((el) => {
    const url = new URL(el.href);
    url.searchParams.set("return_to", location.pathname + location.search);
    el.href = url.toString();
  });
}
