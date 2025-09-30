class SearchBuilder

  module AllSearchResultIdsBuilder
    extend ActiveSupport::Concern

    included do
      self.default_processor_chain += [:all_search_result_ids_processor]
    end

    # Return only primary keys, and return up to ten million of them.
    # We take some pains to request as little as possible from SOLR other than the actual primary keys.
    def all_search_result_ids_processor(solr_parameters)

      # This method runs on all searches, but we exit early unless we actually want this.
      return unless scope.context[:all_search_result_ids] == 'true'

      solr_parameters.delete_if do |k, v|
        k.start_with?('facet')   || k.end_with?("facet.limit") ||
        k.start_with?("hl")      ||
        k.start_with?("stats")
      end

      # It's important for performance that ALL fields in `fl` (in this case just one)
      # have `docValues=true` in solr schema, to avoid major stored field performance hit
      # in this query that could have thousands of results.
      solr_parameters.merge!({fl:"model_pk_ssi", rows: '10000000', hl: 'false', facet: 'false'})
    end
  end
end
