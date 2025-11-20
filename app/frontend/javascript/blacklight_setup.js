
// If we wanted to, we could pick and choose which elements to import in the standard JS way,
// which can work, but BL isn't tested very well for it. We'll just import all of BL for now.
import Blacklight from 'blacklight-frontend';

//****************
//
// Customize Blacklight modal to add support for form submission in modal
// offered upstream at https://github.com/projectblacklight/blacklight/pull/3772
//
// Note we do still CALL upstream func here, so changes upstream can break this patch.
// We should test locally for sure.


const modal = Blacklight.Modal;

modal.triggerformSelector  = 'form[data-blacklight-modal~=trigger]';
modal.preserveFormSelector = modal.modalSelector + ' form[data-blacklight-modal~=preserve]';


modal.modalAjaxFormSubmit = function(e) {
  e.preventDefault();

  const closest = e.target.closest(`${modal.triggerFormSelector}, ${modal.preserveFormSelector}`);

  const method = (closest.getAttribute("method") || "GET").toUpperCase();
  const formData = new FormData(closest);
  const formAction = closest.getAttribute('action');

  const href = (method == "GET") ? `${ formAction }?${ new URLSearchParams(formData).toString() }` : formAction;
  const fetchArgs = {
    headers: { 'X-Requested-With': 'XMLHttpRequest' }
  }

  if (method != "GET") {
    fetchArgs.body = formData;
    fetchArgs.method = method;
  }

  fetch(href, fetchArgs)
    .then(response => {
       if (!response.ok) {
         throw new TypeError("Request failed");
       }
       return response.text();
     })
    .then(data => modal.receiveAjax(data))
    .catch(error => modal.onFailure(error));
}

document.addEventListener('submit', (e) => {
  if (e.target.closest(`${modal.triggerFormSelector}, ${modal.preserveFormSelector}`)) {
    modal.modalAjaxFormSubmit(e)
  }
});

//
// End customize Blacklight modal for forms
//
// ***********************


import BlacklightRangeLimit from "blacklight-range-limit";
BlacklightRangeLimit.init({onLoadHandler: Blacklight.onLoad });

