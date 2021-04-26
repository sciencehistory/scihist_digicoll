module RspecHelper
  module TomSelect

    # A helper for Capyabara tests that need to set values from a tom-select.js input.
    #
    # This is a really hacky approach using execute_javascript, but it works. Not sure if there's
    # a better way, we could try actually interacting with the on-screen tom-select-provided UI,
    # but we're taking the easy way out for now.
    #
    # @param option_id can be the `id` value of an option in the select, OR for select multiple inputs,
    #   can be an array of such IDs.
    #
    # @example tom_select("#select_id", option_id: "2")
    # @example tom_select("#select_id", option_id: ["2", "10"]) # `multiple` input.
    def tom_select(select_selector, option_id:)
      js_str = %Q(document.querySelector("#{select_selector}").tomselect.setValue(#{option_id.inspect}))
      execute_script(js_str)
    end
  end
end
