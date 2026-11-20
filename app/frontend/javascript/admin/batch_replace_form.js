// Batch replace metadata form: for attributes with a controlled list of values
// (form's data-controlled-values), show old/new value as select menus, not text inputs.
import domready from 'domready';

domready(function() {
  const form = document.querySelector("form[data-controlled-values]");
  if (!form) { return; }

  const controlled = JSON.parse(form.dataset.controlledValues);
  const fieldSelect = form.querySelector("#field_name");

  // Most of our fields use simple text input, but some use select.
  // Given an id (old_value or new_value input), a list of select
  // options or blank, and a current value, swap in the correct input type.
  function buildInput(id, options, value) {
    let input;
    if (options) {
      input = document.createElement("select");
      input.className = "form-select";
      input.add(new Option("Select a value...", ""));
      options.forEach(([label, optionValue]) => input.add(new Option(label, optionValue)));
      // blank out a value that isn't in the list
      input.value = options.some(([, optionValue]) => optionValue === value) ? value : "";
    } else {
      input = document.createElement("input");
      input.type = "text";
      input.className = "form-control";
      input.value = value;
    }
    input.id = input.name = id;
    input.required = true;
    return input;
  }

  // Swap old/new value inputs to match the selected attribute, keeping entered values where they fit.
  function installAppropriateInputs() {
    const options = controlled[fieldSelect.value];

    ["old_value", "new_value"].forEach(function(id) {
      const current = form.querySelector("#" + id);
      current.replaceWith(buildInput(id, options, current.value));
    });
  }

  fieldSelect.addEventListener("change", installAppropriateInputs);
  installAppropriateInputs();
});
