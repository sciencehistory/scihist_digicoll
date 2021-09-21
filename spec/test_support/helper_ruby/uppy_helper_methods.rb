module UppyHelperMethods
  # Uppy is a JS library for a file upload UI. In our tests, we need to sometimes add a file through it.
  # This can't be totally automated 'naturally' because capybara can't automate OS file choosing dialog.
  #
  # We found an "around the back" way that works, at least at present, if we attach the file to
  # the hidden file input that we wrapped uppy around, it works!
  #
  # input_name is the value of the name attribute  on the hidden field input, eg `<input name="X">
  #
  # In uppy 2.x, there can be more than one hidden file input in the DOM, but just picking
  # the first one works.
  def add_file_via_uppy_dashboard(input_name:, file_path:)
    attach_file input_name, file_path.to_s, make_visible: true, match: :first
  end
end
