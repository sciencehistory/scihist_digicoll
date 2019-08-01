# Controller for the featured topic show page.
#
class FeaturedTopicController < CatalogController
  before_action :set_featured_topic

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

  configure_blacklight do |config|
    # Our custom sub-class to limit just to items in the featured topic.
    config.search_builder_class = ::SearchBuilder::WithinFeaturedTopicBuilder
  end

  private

  def search_service_context
    { slug: slug }
  end

  def presenter
    @presenter ||= FeaturedTopicShowDecorator.new(featured_topic)
  end
  helper_method :presenter

  def featured_topic
    @featured_topic
  end

  def set_featured_topic
    @featured_topic ||= FeaturedTopic.from_slug(slug).tap do |ft|
      if ft.nil?
        raise ActionController::RoutingError.new("No Featured Topic matches `#{slug}`")
      end
    end
    puts @featured_topic.solr_fq
  end

  def slug
    params[:slug]
  end
  helper_method :slug

end
