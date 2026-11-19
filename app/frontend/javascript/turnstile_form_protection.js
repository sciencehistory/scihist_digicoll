// Renders Cloudflare Turnstile into patron form placeholders
//
// Invokved on page load and Blacklight modal event, so to look for a data-trigger='scihist-auto-cf-turnstile
// in modal or original page load. If found, we invoke Turnstile using Turnstile explict rendering
// for after-page-load.
//
// So can be used to add turnstile protection to forms that will appear adn be submitted within
// blacklight modals.
//
// Server side logic is in TurnstileFormProtection.
import domready from 'domready';

const SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";
const SELECTOR = "[data-trigger='scihist-auto-cf-turnstile']:not([data-turnstile-rendered])";

let scriptLoaded;

function loadTurnstileScript() {
  scriptLoaded ||= new Promise((resolve, reject) => {
    const script = document.createElement("script");
    script.src = SCRIPT_URL;
    script.onload = resolve;
    script.onerror = reject;
    document.head.appendChild(script);
  });
  return scriptLoaded;
}

function renderTurnstiles() {
  if (!document.querySelector(SELECTOR)) return;

  loadTurnstileScript().then(() => {
    document.querySelectorAll(SELECTOR).forEach((el) => {
      el.dataset.turnstileRendered = "true";

      // submit waits for a token; disabled only once rendered, so a failed script load never sticks
      const submits = el.closest("form")?.querySelectorAll("[type='submit']") || [];
      const setSubmitsDisabled = (disabled) => submits.forEach((button) => { button.disabled = disabled; });
      setSubmitsDisabled(true);

      window.turnstile.render(el, {
        sitekey: el.dataset.sitekey,
        callback: () => setSubmitsDisabled(false),
        "expired-callback": () => setSubmitsDisabled(true),
        "error-callback": () => setSubmitsDisabled(false) // let server show its error message
      });
    });
  });
}

domready(renderTurnstiles);
document.addEventListener("loaded.blacklight.blacklight-modal", renderTurnstiles);
