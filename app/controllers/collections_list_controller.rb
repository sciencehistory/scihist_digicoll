# Front-end controller to list public collections.
class CollectionsListController < ApplicationController
  def index
    @collections = Collection.where("published = true").
      with_representative_derivatives
    render :template => "collections/index"
  end
end