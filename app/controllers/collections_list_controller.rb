# Front-end controller to list public collections.
class CollectionsListController < ApplicationController

  def index
    # TODO filter collections the viewer shouldn't see.
    # TODO avoid n+1 queries by preloading some stuff.
    @collections = Collection.all
    render :template => "collections/index"
  end

end
