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
# * When we write tests for a 'ViewModel', we make them rspec type :view or :helper, either
#   seems to work fine. Those will be set up by rspec to have a view_context for our draper-based
#   view model. You can set the result of a view model render method to a variable or 'let' declaration,
#   say "rendered" for consistency with real view specs. If you put it in a Nokogiri object, you
#   can test it capybara matchers:
#       let(:rendered) { Nokogiri::HTML.fragment( IndexResultDisplay.new(work).display ) }
#       expect(rendered).to have_text("some string")
#       expect(rendered).to have_selector("li", text: "text contents")
class ViewModel < Draper::Decorator
  # we intentionally do NOT do draper `delegate_all`, but intentionally DO
  # do include all Rails helpers in the ViewModel with:
  include Draper::LazyHelpers

end
