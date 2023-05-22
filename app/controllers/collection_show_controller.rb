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
  before_action :collection, :check_auth

  ORAL_HISTORY_DEPARTMENT_VALUE = "Center for Oral History"

  def index
    super
    @collection_opac_urls = CollectionOpacUrls.new(collection)
    @related_link_filter ||= RelatedLinkFilter.new(collection.related_link)
  end

  # This method can be overridden from blacklight to provide *dynamic* blacklight
  # config
  def blacklight_config
    # While the main Oral History collection gets it's own custom controller,
    # with it's own config and templates --  we have sub-collections that get
    # this generic controller.  If we have one here, use the config from that
    # main OH Controller, to get OH-customized facets and any other search config.
    if collection.department == ORAL_HISTORY_DEPARTMENT_VALUE
      CollectionShowControllers::OralHistoryCollectionController.blacklight_config
    else
      super
    end
  end

  def facet
    # Note: params[:id] is being hogged by Blacklight; it refers to the
    # facet id. Thus, to refer to the collection's id we'll be
    # using params[:collection_id] instead. This is obviously a departure from
    # the Rails standard.

    unless (params[:id] && blacklight_config.facet_fields[params[:id]])
      raise ActionController::RoutingError, 'Not Found'
    end
    @facet = blacklight_config.facet_fields[params[:id]]

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

    # and we need to make sure collection_id is allowed by BL, don't totally
    # understand this, as of BL 7.25
    config.search_state_fields << :collection_id
  end

  private

  # Our custom SearchBuilder needs to know collection id (UUID)
  def search_service_context
    super.merge!(collection_id: collection.id)
  end

  def check_auth
    authorize! :read, @collection
  end

  def collection
    @collection ||= Collection.find_by_friendlier_id!(params[:collection_id])
  end
  helper_method :collection
end
