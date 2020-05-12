# Front-end controller to list public collections.
class CollectionsListController < ApplicationController
  def index
    @collections = Collection.
      where("published = true").
      order(:title).
      includes(:leaf_representative)
  end
end
