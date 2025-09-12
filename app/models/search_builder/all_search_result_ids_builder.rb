class SearchBuilder

  module AllSearchResultIdsBuilder
    extend ActiveSupport::Concern

    included do
      self.default_processor_chain += [:all_search_result_ids_processor]
    end

    # Return only friendlier_ids, and return up to ten million of them.
    # We take some pains to request as little as possible from SOLR other than the actual friendlier_ids.
    def all_search_result_ids_processor(solr_parameters)

      # This method runs on all searches, but we exit early unless we actually want this.
      return unless scope.context[:all_search_result_ids] == 'true'
  
      solr_parameters.delete_if do |k, v|
        # don't need anything to do with facets
        k.start_with?('facet')     || k.end_with?("facet.limit") ||
        # no need for highlighting
        k.start_with?("hl")      || 
        # certainly don't need stats
        k.start_with?("stats")  
      end

      solr_parameters.merge!({fl:"model_pk_ssi", rows: '10000000', hl: 'false'})
    end
  end
end
