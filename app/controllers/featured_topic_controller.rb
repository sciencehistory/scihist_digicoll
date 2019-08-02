# Controller for the featured topic show page.
#
class FeaturedTopicController < CatalogController
  before_action :set_featured_topic

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
    # Our custom sub-class to limit just to items in the featured topic.
    config.search_builder_class = ::SearchBuilder::WithinFeaturedTopicBuilder
  end

  def context
    search_service_context
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


  def total_count
    #
    #SearchBuilder.new(self).blacklight_config

    #byebug
    # SearchBuilder.new(self).methods
    #SearchBuilder.new(self).processor_chain
    #@total_count ||= repository.search( search_builder.with(params.merge(rows: 0)).query).total
    #byebug
    #SearchBuilder.new(self).rows
    @response.total_count
  end
  helper_method :total_count
end