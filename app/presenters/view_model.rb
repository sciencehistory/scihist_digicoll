# A "View Model" as used here, is a ruby object for producing presentation output, usually HTML.
# It is a kind of "presenter" -- we have other presenters that aren't "View Models", what we call
# a "View Model" is a presenter that has access to Rails helper methods. But View Models live in
# `./app/presenters`.
#
# This superclass uses the [draper](https://github.com/drapergem/draper) gem to provide
# access to Rails helper methods (both standard Rails and local app), including the ability to render
# a rails partial view template (ERB).
#
# The typical public API for a View Model will be something like:
#
#     <%= WorkResultDisplay.new(some_work).display %>
#
# By convention, a View Model will ordinarily have a "display" method that may be it's
# only public API, although if needed other methods/args can be implemented.
#
# While we are using draper to handle getting access to Rails helpers for us, we don't intend
# "view models" to be "decorators" or to have a simple correspondence to a model class, like
# the draper docs lead you do. Instead of a draper "WorkDecorator" that is a "Work" with extra
# presentational logic, we might have a "WorkResultDisplay", which is an object that can render
# the display a work in search results.  View Models correspond to particular 'components' on
# a page, not to models, although they often will be rendering a particular model.
#
# ## Rendering html with Rails helper methods
#
# A view_model `#display` method might programmatically construct some HTML tags for simple
# HTML. All Rails helper methods are available directly on the view model, so you can call
# the Rails `content_tag` method. The Rails [safe_join](https://api.rubyonrails.org/classes/ActionView/Helpers/OutputSafetyHelper.html#method-i-safe_join)
# method is also good to know about.
#
# ## Rendering an ERB template
#
# A view model may wish to use an ERB template for non-trivial HTML, to keep the HTML templates
# nicely readable and separate from logic. Since our draper-based view models have access
# to all Rails helpers, they can simply call `render` to render a partial template.
#
# However, normal Rails `render` looks up partials based on the current controller, which
# we don't really want to do for our View Models. So by convention, we put ERB templates
# for View Models in `./app/views/presenters/`, and call them from View Models with
# `render "/presenters/name_of_template"`. (The template should generally be named
# after the View Model class; sub-directories can be used if desired).
#
# One of the benefits of view models is it makes it more manageable to minimize logic
# in the view template, approaching "logic-less views". Instead, "helper" methods
# can be provided in the View Model itself (they do have to be public), and we
# can pass an instance of the "View Model" in to the template -- by convention,
# we'll pass it in as `view`. We may also want to pass in the `model` (eg a Work)
# for convenience, so the `render` call in a View Model may look like this:
#
#     render "/presenters/name_of_template", model: model, view: self
#
# Now, the View Model ERB template can call "helper" methods on the View Model
# with `view.name_of_method`.  If you wanted to be even more 'pure', you could
# avoid passing in the model and require everything to go through the View Model.
# It may be useful to use Draper's `delegate` method to have the View Model delegate
# some methods to the model.
#
# A template used by a View Model should never call Rails `render` itself to render
# partials -- that'll just get confusing. It can call other View Models though,
# perhaps through methods on it's own owning View Model.
#
# We could enhance the View Model superclass to automatically add `view` and/or
# `model` args to the `render` call -- or to try to do fancier things with
# automatic path lookup for View Model templates -- but for now we're keeping it
# simple and explicit.
#
# ## Arguments to View Model initializers
#
# Often a View Model will only need one argument passed in, often an ActiveRecord model object
# of some kind. The Draper superclass assumes this use case as a happy path, so anything
# with this View Model superclass can already take one argument in it's initializer,
# which will be available in the View Model as `#model`. If you'd like to specify a whitelist
# of allowed classes for the first 'model' arg, see `.valid_model_type_names` below.
#
# If you need additional parameters, one option is the standard draper feature of passing
# in additional "context" like:
#
#       SomeDisplayer.new(some_model, context: { whatever: "you want"})
#
# Pass in a hash as `context` arg, that hash will be available in the ViewModel
# as `context` method, eg `context[:whatever]`.
#
# You could also possibly write the View Model sub-class to take additional "top-level"
# keyword args on initializer, by overriding the draper-provided `initialize` method and
# calling `super` appropriately.
#
# ## Testing View Models
#
# When writing a spec for a 'view model', you can use the rspec :decorator type (added by draper), or the
# :view or :helper type (built into rspec) -- all should work.
#
# In any case, you'll want to test the output, usually HTML. Unlike standard Rails "view" tests, you don't
# automatically have output in a variable called "rendered", but you can just assign the output yourself
# to a local variable or an rspec `let` block, parsed with Nokogiri.
# Assign to a variable called `rendered` or whatever else you like.
# Then you can use the rspec `have_selector` or `have_text` matchers (which are actually provided by the
# capybara gem).
#
#     let(:rendered) { Nokogiri::HTML.fragment( WorkResultDisplay.new(work).display ) }
#     it "does something" do
#       expect(rendered).to have_text("succeeded")
#       expect(rendered).to have_selector("ul > li.some-class", text: "some text")
#     end
#
# It is all a bit manual, perhaps we can provide some glue to eliminate the boilerplate later.
#
# ## Automatic test setup
#
# In our spec_helper.rb, we tell rspec that for any tests in "spec/presenters", the `:decorator`
# spec type should be used as default:
#
#     config.define_derived_metadata file_path: %r{spec/presenters} do |metadata|
#       metadata[:type] = :decorator
#     end
#
# And, just in case we end up using any of our 'view models' in a :helper or :view test,
# we tell draper to clean up it's test context in those types of specs, per
# [draper documentaton](https://github.com/drapergem/draper#view-context-leakage). We did observe
# "leakage" (oddly failing specs) without this cleanup.
#
#     config.before(:each, type: :view) { Draper::ViewContext.clear! }
#     config.before(:each, type: :helper) { Draper::ViewContext.clear! }
class ViewModel < Draper::Decorator
  # we intentionally do NOT do draper `delegate_all`, but intentionally DO
  # do include all Rails helpers in the ViewModel with:
  include Draper::LazyHelpers

  # Workaround weird Draper bug/gotcha interaction with ActiveRecord
  # https://github.com/drapergem/draper/issues/859
  delegate :id

  def initialize(model, *other_args)
    if self.class.valid_model_type_names
      unless self.class.valid_model_type_names.any? { |t| model.kind_of?(t.constantize) }
        raise ArgumentError.new("#{self.class.name} arg must be of one of type #{self.class.valid_model_type_names.inspect}, but was #{model.class.name.inspect}")
      end
    end

    super
  end

  # A "macro" method you can use in your View Model sub-class to specify one or more
  # class names (as Strings), to require that the first argument to the ViewModel initializer,
  # the draper "model", be one of the mentioned classes.
  #
  # It's sometimes useful to allow `nil` to be passed to a View Model, to have special nil-handling
  # handled inside the view model. If so, just specify the ruby stdlib `NilClass` as an allowed class.
  #
  # @example
  #   class Something < ViewModel
  #     valid_model_type_names "String"
  #   end
  #
  # @example
  #   class Something < ViewModel
  #     valid_model_type_names "Collection", "NilClass"
  #   end
  #
  # If you specify `valid_model_type_names`, and a caller tries to initialize a ViewModel
  # subclass with an arg that isn't one of the allowed classes, an ArgumentError will be raised.
  def self.valid_model_type_names(*args)
    if args.present?
      unless args.all?(String)
        raise ArgumentError.new("All args to valid_model_type_names should be String class names, not #{args.inspect}")
      end
      @valid_model_type_names = args
    end

    @valid_model_type_names
  end
end
