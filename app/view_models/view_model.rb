# A superclass for our "view models", which are just objects that render a certain thing, big or small,
# in an HTML page. (Or at least usually HTML)
#
# They are _basically_ just Draper "decorators" but used in a certain way that's different
# from what Draper README leads you to. While draper decorators start out assuming you have
# a decorator that belongs to a model and are named accordingly, our view models are for a
# _part of a page_, and are named accordingly, like `IndexResultDisplay`. They usually end
# in `Display`.
#
# They usually do still take a single model argument in initializer, although it might accept
# multiple model types polymorphically.  A ViewModel will have one or more public methods that
# can be used to render some html, often we only need one and by convention we will call it 'show'.
#
#
#     <%= IndexResultDisplay.new(some_model).show %>
#
# * if your ViewModel wants to create some HTML in a method (not just ERB), the Rails helper method content_tag
#   is useful, plus `safe_join` for concatenating differnet content_tag and plain string outputs in an HTML-escape-safe
#   way.
#
# * Additional params can be passed in (standard draper feature) like:
#       IndexResultDisplay.new(some_model, context: { whatever: "you want"})
#   Those keys will be available in the view model as `context[:whatever]`
#
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
# In our spec_helper.rb, we tell rspec that for any tests in "spec/view_models", the `:decorator`
# spec type should be used as default:
#
#     config.define_derived_metadata file_path: %r{spec/view_models} do |metadata|
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

end
