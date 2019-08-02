# Controller for the featured topic show page.
class FeaturedTopicController < CatalogController
  before_action :set_featured_topic

  # Note: params[:id] is being hogged by Blacklight; it refers to the
  # facet id. Thus, to refer to the collection's id we'll be
  # using params[:collection_id] instead. This is obviously a departure from
  # the Rails standard.
  def facet
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
    # Limit just to items in the featured topic.
    config.search_builder_class = ::SearchBuilder::WithinFeaturedTopicBuilder
  end

  private

  def search_service_context
    { slug: params[:slug] }
  end

  def set_featured_topic
    @featured_topic ||= FeaturedTopic.from_slug(params[:slug]).tap do |ft|
      if ft.nil?
        raise ActionController::RoutingError.new("No Featured Topic matches `#{params[:slug]}`")
      end
    end
  end

  def total_count
    @response.total_count
  end
  helper_method :total_count

end