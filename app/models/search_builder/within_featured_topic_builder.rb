class SearchBuilder
  # Applies a limit to search just within a given featured topic.
  #
  # :slug needs to be provided in context.
  #
  # Used on FeaturedTopicController.
  class WithinFeaturedTopicBuilder < ::SearchBuilder
    extend ActiveSupport::Concern

    self.default_processor_chain += [:within_featured_topic]

    def within_featured_topic(solr_parameters)
      featured_topic = FeaturedTopic.from_slug(blacklight_params[:slug])
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << featured_topic.solr_fq
    end
  end
end
