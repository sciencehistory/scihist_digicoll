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
# * When we write tests for a 'ViewModel', we make them rspec type "view" (or helper?), because
#   that's the one rspec (with draper support) provides the necessary infrastructure support for executing
#   view code antesting what gets rendered. (Need to test/confirm)
class ViewModel < Draper::Decorator
  # we intentionally do NOT do draper `delegate_all`, but intentionally DO
  # do include all Rails helpers in the ViewModel with:
  include Draper::LazyHelpers

end
