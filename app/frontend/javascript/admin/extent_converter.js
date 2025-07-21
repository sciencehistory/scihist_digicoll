import domready from 'domready';
domready(function() {
  if (document.querySelector(".extent-converter")) {
    const INCH_TO_CM = 2.54;
    const fields = {
      inches: {
        el: document.querySelector(".extent-converter input.inches"),
        convert: (val) => val * INCH_TO_CM,
        target: "centimeters"
      },
      centimeters: {
        el: document.querySelector(".extent-converter input.centimeters"),
        convert: (val) => val / INCH_TO_CM,
        target: "inches"
      }
    };

    function sanitizeInput(value) {
      return value.replace(/[^0-9.]/g, '').replace(/(\..*?)\..*/g, '$1');
    }

    function updateField(sourceUnit) {
      const source = fields[sourceUnit];
      const target = fields[source.target];

      const cleanValue = sanitizeInput(source.el.value);
      source.el.value = cleanValue;

      const parsed = parseFloat(cleanValue);
      if (!isNaN(parsed)) {
        target.el.value = source.convert(parsed).toFixed(2);
      } else {
        target.el.value = '';
      }
    }

    fields.inches.el.addEventListener("input", () => updateField("inches"));
    fields.centimeters.el.addEventListener("input", () => updateField("centimeters"));
  }
});