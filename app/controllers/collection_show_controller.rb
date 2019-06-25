# Controller for public individual collection 'show' page.
#
# It's in it's own controller just for that, so it can inherit CatalogController
# for properly configured Blacklight search behavior.
#
# For that reason, the action for showing an individual collection is #index, so
# we can easily use built-in Blacklight search behavior and search views (facets etc).
# There may be a less hacky way to do this, esp in Blacklight 7, but this is a port of
# what was in chf_sufia. There also may not be.
class CollectionShowController < CatalogController
  before_action :set_collection

  def index
    authorize! :read, @collection
    super
  end

  private

  # Technically overrides a Blacklight method, although we do our own thing with it
  def presenter
    @presenter ||= CollectionShowDecorator.new(collection)
  end
  helper_method :presenter

  def collection
    @collection
  end
  helper_method :collection

  def set_collection
    @collection = Collection.find_by_friendlier_id!(params[:id])
  end
end
