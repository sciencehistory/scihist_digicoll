# Controller for the featured topic show page.
class FeaturedTopicController < CatalogController
  before_action :set_featured_topic

  # params[:id] is being hogged by Blacklight.
  # It refers to the facet id.
  def facet
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
    # Limit just to items in the featured topic.
    config.search_builder_class = ::SearchBuilder::WithinFeaturedTopicBuilder

    # And we need to make sure the :slug param is allowed by blacklight,
    # don't totally understand why, as of BL 7.25
    config.search_state_fields << :slug
  end

  private

  def search_service_context
    super.merge!(slug: params[:slug])
  end

  def set_featured_topic
    @featured_topic ||= FeaturedTopic.from_slug(params[:slug]).tap do |ft|
      if ft.nil?
        raise ActionController::RoutingError.new("No Featured Topic matches `#{params[:slug]}`")
      elsif ft.redirect_path_type?
        raise ActionController::RoutingError.new("Featured topic for `#{params[:slug]}` is a :path redirect type, controller is not applicable")
      end
    end
  end

  def total_count
    @total_count ||= begin
      # We need to fight with Blacklight a bit to get the results which have been
      # limited by our "slug", but EXCLUDING any current search query or facet limits.
      #
      # This is based on reverse-engineering of the very abstracted stuff BL is
      # doing, and is probably kind of fragile, sorry. :(

      empty_search_state = search_state_class.new(params.slice(:controller, :action, :slug), blacklight_config, self)

      # In future BL versions you may need to remove .to_h, just `search_service.search_builder.with(empty_search_state)`
      builder = search_service.search_builder.with(empty_search_state.to_h)
      builder.rows = 0 # we don't want any actual results back, just search metadata

      response = search_service.repository.search(builder)

      response.total_count
    end
  end
  helper_method :total_count

end
