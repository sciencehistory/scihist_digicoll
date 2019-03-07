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


end
