// Provide auto-suggest from qa (questioning authority) endpoints. (Or really anything that returns results
// in the same format as qa, but qa is what it is intended for).
//
// Add to a text field the HTML attribute `data-scihist-qa-autocomplete=/path/to/qa/search`, and your
// text field, as you type in it, will get dropdown menu of sugggestions from the QA-delivered vocabulary.
// You can still enter 'manual' entries that were not from vocabulary.
//
// For qa vocabularly sources that return a :label and a :value, like FAST, the :label shows up
// in the suggestions, but when chosen the :value is what gets put in the textbox. For FAST,
// qa delivers results such as label=`Pennsylvania--Philadelphie USE Pennsylvania--Philadelphia`,
// value=`Pennsylvania--Philadelphia`.
//
// The `id` attribute returned in qa JSON response (which might be unique identifier from FAST or
// other vocabulary) -- is currently ignored, not displayed or preserved in any way.
//
// All this behavior is meant to match what we had in chf_sufia with hydra-editor or whatever other samvera
// dependencies were providing (not sure)
//
//
// ## Implementation
//
// The auto-suggest from remote AJAX source uses the devbridge-autocomplete/jquery-autocomplete
// jQuery plugin. https://github.com/devbridge/jQuery-Autocomplete . This was the most suitable
// pre-made thing I found with extensive looking (including trying to find things not dependent
// on jQuery).
//
// It still required a bit of hacking to get it to work. In particular, to get the behavior above
// for "USE" examples, where the string shown in the suggestions is not the thing that ends up
// in your text box if you select it -- that really confused the jquery-autocomplete plugin,
// it kept wanting to show a new set of suggestions when to our UX nothing had changed.
//
// This was made worse by a bug around onFocus (https://github.com/devbridge/jQuery-Autocomplete/issues/766)
// -- although really we wanted to disable "show suggestions onFocus" altogether to match
// chf_sufia behavior.
//
// We fix things up mostly with a few kind of hacky private API interventions into the plugin --
// but hey, this still isn't much code, and the plugin isn't getting much development so
// it probably won't break.
//
// We could try to add features we need upstream (https://github.com/devbridge/jQuery-Autocomplete/issues/769),
// we could consider forking this (it's not actually much code), or we could in the future provide a
// better alternate tool for a JS auto-suggest UI.

import 'jquery'

// https://github.com/devbridge/jQuery-Autocomplete
import 'devbridge-autocomplete';

var errorContainer =  $('<div class="autocomplete-no-suggestion"></div>')
  .html("<i class='fa fa-exclamation-triangle' aria-hidden='true'></i> Error fetching results").get(0);

function addAutocomplete(element) {
    var input_el = $(element);
    var qa_search_url = input_el.data("scihist-qa-autocomplete");

    input_el.autocomplete({
      deferRequestBy: 600, // bunch keystrokes into 600ms groups for requests
      paramName: "q",
      minChars: 2,
      maxHeight: 700,
      preserveInput: true, // our custom onSelect instead
      showNoSuggestionNotice: true,
      serviceUrl: qa_search_url,

      onSearchError: function (query, jqXHR, textStatus, errorThrown) {
        console.log("autocomplete error fetching results: " + textStatus + ": " + errorThrown);

        // Pretty hacky way to show error message in dropdown, reaching into
        // autocomplete internals. Based on how autocomplete shows no-results message.
        var container = $($(this).autocomplete().suggestionsContainer)
        container.empty();
        container.append(errorContainer);
        container.show();
      },

      transformResult: function(response) {
        // not sure why it's a string instead of json already...
        if (typeof response == "string") {
          response = JSON.parse(response);
        }

        return {
          suggestions: $.map(response, function(dataItem) {
            return { value: dataItem.label, data: dataItem.value };
          })
        };
      },

      onSelect: function(suggestion) {
        // Set the text input to `data`, not the `value` that was being shown.
        //
        // However, the autocomplete JS is confused if we set a value to the textbox
        // different than the the string that was displayed in the menu, and wants
        // to show suggestions for the new string. We disable and re-enable
        // only on additional text entry in the box, to get around this in a hacky way.
        //
        // Still has SOME weird cases where autosuggest will show up when you don't think
        // you've changed anything, but minimized and that's not too horrible.
        var input = $(this);
        input.autocomplete('disable');
        this.value = suggestion.data || suggestion.value;

        $(this).one("keydown", function() { input.autocomplete("enable") })
      }
    });

    // hack to break in and disable the autocomplete onFocus, cause we don't
    // WANT to autocomplete on focus, plus it's broken with 'disabled' state,
    // that keeps us from working around re-suggest on select
    input_el.autocomplete().onFocus = function() {};
}

// Uses jquery, assumes it exists in `window` for now.

jQuery( document ).ready(function() {
  // When an input is focused, see if it already has autocomplete plugin added,
  // if not add it. This makes it work for suitable new input elements added
  // to the DOM (in response to 'add another' links), even if they weren't
  // there on page at load.
  $("body").on("focus", "*[data-scihist-qa-autocomplete]", function(event) {
    var el = $(event.target);
    if (! el.data("autocomplete")) {
      // hasn't already had autocomplete plugin added, so add it.
      addAutocomplete(event.target)
    }
  });
});
