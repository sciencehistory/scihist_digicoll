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


  #Override from Blacklight: displays values and pagination links for a single facet field
  #
  # We need to override to change URL to get facet_id out of :id, which we use for our collection.
  # Need to copy-and-paste-and-change implementation, which is unfortunate.
  def facet
    unless params.key?(:facet_id)
      redirect_back fallback_location: { action: "index", id: params[:id] }
      return
    end

    @facet = blacklight_config.facet_fields[params[:facet_id]]
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


  private

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
    @collection = Collection.find_by_friendlier_id!(params[:id])
  end

  # override from Blacklight to put the facet id in :facet_id instead of :id, so we can keep
  # :id for our parent collection id.
  # Goes with overridden #facet above.
  def search_facet_path options = {}
    if options.has_key?(:id)
      options[:facet_id] = options.delete(:id)
    end
    super(options)
  end
end
