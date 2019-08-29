import 'jquery'

// https://github.com/devbridge/jQuery-Autocomplete
import 'devbridge-autocomplete';

// Uses jquery, assumes it exists in `window` for now.

jQuery( document ).ready(function() {

  $("*[data-scihist-autocomplete]").each(function() {
    var input_el =$(this);
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
        // would like to show an error in browser, but haven't figured out a good way to. :(
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
  });
});
