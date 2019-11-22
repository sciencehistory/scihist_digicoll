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
  before_action :set_collection, :check_auth

  # index action inherited from CatalogController, that's what we use.

  def facet
    # Note: params[:id] is being hogged by Blacklight; it refers to the
    # facet id. Thus, to refer to the collection's id we'll be
    # using params[:collection_id] instead. This is obviously a departure from
    # the Rails standard.

    @facet = blacklight_config.facet_fields[params[:id]]
    raise ActionController::RoutingError, 'Not Found' unless @facet

    @response = search_service.facet_field_response(@facet.key)
    @display_facet = @response.aggregations[@facet.field]
    @pagination = facet_paginator(@facet, @display_facet)
    respond_to do |format|
      format.html do
        # Draw the partial for the "more" facet modal window:
        return render layout: false if request.xhr?
        # Otherwise draw the facet selector for users who have javascript disabled.
      end
      format.json
    end
  end

  configure_blacklight do |config|
    # Our custom sub-class to limit just to docs in collection, with collection id
    # taken from params[:collection_id]
    config.search_builder_class = ::SearchBuilder::WithinCollectionBuilder
  end

  private

  # Our custom SearchBuilder needs to know collection id (UUID)
  def search_service_context
    super.merge!(collection_id: collection.id)
  end

  def check_auth
    authorize! :read, @collection
  end

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
    @collection = Collection.find_by_friendlier_id!(params[:collection_id])
  end

end
