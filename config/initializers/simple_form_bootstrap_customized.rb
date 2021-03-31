# frozen_string_literal: true

# Additional generator  we added locally to be after simple_form_bootstrap.rb alphabetically,
# so we can re-define some things from that generated file.

SimpleForm.setup do |config|
  # Default class for buttons
  config.button_class = 'btn btn-primary'


  # Custom wrapper for horizontal form with our col-left
  config.wrappers :scihist_horizontal_form, tag: 'div', class: 'form-group row', error_class: 'form-group-invalid', valid_class: 'form-group-valid' do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.wrapper tag: "div", class: 'col-left col-form-label' do |ba|
      ba.use :label, wrapper: false
    end
    b.wrapper :grid_wrapper, tag: 'div', class: 'col-sm' do |ba|
      ba.use :input, class: 'form-control', error_class: 'is-invalid'
      ba.use :full_error, wrap_with: { tag: 'div', class: 'invalid-feedback' }
      ba.use :hint, wrap_with: { tag: 'small', class: 'form-text text-muted' }
    end
  end

  config.wrappers :scihist_search_form_horizontal, tag: 'div', class: 'form-group row', error_class: 'form-group-invalid', valid_class: 'form-group-valid' do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly
    b.use :label, class: 'col-sm-2 col-form-label'
    b.wrapper :grid_wrapper, tag: 'div', class: 'col-sm-10' do |ba|
      ba.use :input, class: 'form-control', error_class: 'is-invalid'
      ba.use :hint, wrap_with: { tag: 'small', class: 'form-text text-muted scihist-hint mb-2 mt-0' }
      ba.use :full_error, wrap_with: { tag: 'div', class: 'invalid-feedback' }
    end
  end


  # For use where we want to lay out the whole form ourselves. It does NOT include a label,
  # you are responsible for including a label yourself.
  #
  # It does include both hint and error UNDER the input.
  #
  # Since you are resposible for label, we can't highlight the whole label/input area in red, only
  # the input itself.
  #
  # This was based on the out-of-the-box simple_form bootstrap :inline_form wrapper, but
  # we don't even want a screen-reader-only label, we're going to do the label ourselves elsewhere.
  # And we want the hint under the input, because works better for our repeatable sections, even
  # though it's a bit confusing when the error shows up too.
  config.wrappers :scihist_no_label_input, tag: 'span', error_class: 'form-group-invalid', valid_class: 'form-group-valid' do |b|
    b.use :html5
    b.use :placeholder
    b.optional :maxlength
    b.optional :minlength
    b.optional :pattern
    b.optional :min_max
    b.optional :readonly

    b.use :input, class: 'form-control', error_class: 'is-invalid'
    b.use :error, wrap_with: { tag: 'div', class: 'invalid-feedback' }
    b.optional :hint, wrap_with: { tag: 'small', class: 'form-text text-muted scihist-hint mb-2 mt-0' }
  end



end
