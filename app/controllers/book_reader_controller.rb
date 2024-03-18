# We're going to deliver Internet Archive Book Reader as it's own page, that we'll
# embed in an iframe. this is a use case the book reader supports intentionally.
#
# Why are we interested?
#
# 1. It keeps the Javascript for the book reader completely separate from the rest of our app.
#   * The BookReader JS is fairly complicated and heavy-weight, we don't want to include it in all
#     or even any of our pages
#   * But even worse, the book reader JS _conflicts_ with some of our JS
#
# 2. We were having trouble getting the book reader to display in a Boostrap modal
#    directly, will it work out better in an iframe inside the modal?
class BookReaderController < ApplicationController
  # No layout, we control the whole thing in the single .html.erb
  layout false

  # GET /book_reader/:id (work friendlier_id)
  def show
  end
end
