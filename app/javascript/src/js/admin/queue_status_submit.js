// We have Digitiation Queue Item "status" forms that consist only of
// a select menu (and submit button), and use rails-ujs remote=true
// to do a remote form.
//
// We make them auto-submit on select menu selection, and also add some
// things to show progress spinner and handle errors.
//
// The rails-ujs stuff we're using here is kind of poorly documented.
// We could rewrite it to not use at all? But here are some references
//
// https://guides.rubyonrails.org/working_with_javascript_in_rails.html#remote-elements
// https://guides.rubyonrails.org/working_with_javascript_in_rails.html#rails-ujs-event-handlers
// https://github.com/rails/rails/issues/29546#issuecomment-313981539
//
// Our actual HTML uses the poorly documented rails-ujs "data-disable-with" feature to
// have a progress spinner and disable form when in proress.

import domready from 'domready';

domready(function() {
  function notOurForm(form) {
    return !(form && form["data-auto-submit"] == "true");
  }


  // On digitization queue item status select menu change, auto-submit form
  document.body.addEventListener("input", function(event) {
    var changed = event.target;
    var form = changed.closest("form")
    if (changed.tagName != "SELECT" || notOurForm(form))  {
      return;
    }

    Rails.fire(form, 'submit');
  });


  // The "ajax:" events are custom events from rails-ujs

  document.body.addEventListener('ajax:error', function(event) {
    var form = event.target;

    if (notOurForm(form)) {
      return;
    }

    // Make it show what we actually think is saved, not updated value.
    form.reset();
    //debugger;
    // And warn the user, with info for developer in console
    var detail = event.detail;
    var data = detail[0], status = detail[1], xhr = detail[2];
    console.error("DigitizationQueueItem AJAX status change failed\n\n" + status + " " + data);
    alert("Uh oh, digitization Queue Item status change failed!");
  });


  document.body.addEventListener('ajax:success', function(event) {
    var form = event.target;

    if (notOurForm(form)) {
      return;
    }

    // Fix the select value to record this is what we think it is, so if
    // we need to rollback on error in future, it's to this.
    var select = form.querySelector("select");
    var updatedValue = select.value;
    select.querySelector("option[selected]").removeAttribute("selected");
    select.querySelector("option[value='" + updatedValue + "']").setAttribute('selected', true);
  })

});
