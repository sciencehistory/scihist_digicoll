class SearchBuilder
  # Applies a limit to search just within a given collection, filtering on solr
  # field where we've stored the containing collection ids.
  #
  # :collection_id needs to be provided in context, the actual UUID pk of collection,
  # since that's what we index.
  #
  # Used on CollectionShowController search within a collection
  class WithinFeaturedTopicBuilder < ::SearchBuilder
     extend ActiveSupport::Concern

    # self.default_processor_chain += [:within_featured_topic]

    def within_featured_topic(solr_parameters)
      featured_topic = FeaturedTopic.from_slug(blacklight_params[featured_topic_slug])
      solr_parameters[:fq] ||= []
      solr_parameters[:fq] << solr_params[:fq] << synthetic_category.solr_fq
    end


    # private

    # def subject
    #   scope.context.fetch(:subject)
    # end

    # def genre
    #   scope.context.fetch(:genre)
    # end


  end
end
