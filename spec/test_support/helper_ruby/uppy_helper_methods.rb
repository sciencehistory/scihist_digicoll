module UppyHelperMethods
  # Uppy is a JS library for a file upload UI. In our tests, we need to sometimes add a file through it.
  # This can't be totally automated 'naturally' because capybara can't automate OS file choosing dialog.
  #
  # An around the back way that works is attaching directly to the hidden real <input> behind
  # uppy input, but to get capybara to interact wiht it, it has to be visible!
  #
  # Capybara has a make_visible command that is SUPPOSED to do that, but it doesn't
  # seem to do enough for uppy, so we use our own custom JS to remove all classes,
  # all inline styles, and any `hidden` attribute, hoping to make it visible!
  #
  # @param input_name [String] the value of the name attribute  on the hidden field input, eg `<input name="X">
  #
  # In uppy 2.x, there can be more than one hidden file input in the DOM, but just picking
  # the first one works.
  def add_file_via_uppy_dashboard(input_name:, file_path:)
    # make sure it's there even hidden for us to exec JS oni t
    first("input[name=\"#{input_name}\"]", visible: :all)

    # exec JS to try to make it visible!
    execute_script("let _inp = document.querySelector('input[name=\"#{input_name}\"]'); _inp.style = ''; _inp.hidden = false; _inp.classList = null;")

    # Now ask capybara to attach file, also asking capybara to do what it can to make visible
    # if needed -- but not only is this not working, it's CAUSING problems??
    attach_file input_name, file_path.to_s, match: :first #make_visible: true
  end
end
