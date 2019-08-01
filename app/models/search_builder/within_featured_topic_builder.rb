class SearchBuilder
  # Applies a limit to search just within a given collection, filtering on solr
  # field where we've stored the containing collection ids.
  #
  # :collection_id needs to be provided in context, the actual UUID pk of collection,
  # since that's what we index.
  #
  # Used on CollectionShowController search within a collection
  class WithinFeaturedTopicBuilder < ::SearchBuilder
    # class_attribute :collection_id_solr_field, default: "collection_id_ssim"

    # self.default_processor_chain += [:within_collection]

    # def within_collection(solr_parameters)
    #   solr_parameters[:fq] ||= []
    #   solr_parameters[:fq] << "{!term f=#{collection_id_solr_field}}#{collection_id}"
    # end

    # private

    # def collection_id
    #   scope.context.fetch(:collection_id)
    end
  end
end
