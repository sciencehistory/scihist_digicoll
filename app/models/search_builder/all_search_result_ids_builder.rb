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

      solr_parameters.except!(*unneeded_keys)

      # remove all facet limit info as well:
      facet_limit_keys = solr_parameters.keys.select  {|k| k.include? 'facet.limit'}
      solr_parameters.except!(*facet_limit_keys)
  
      solr_parameters.merge!({fl:"id", rows: '10000000'})
    end

    def unneeded_keys
      @unneeded_keys ||= [
        # Keep the sort for now
        # ['sort']

        # don't need stats
        ["stats", "stats.field"],

        # don't need highlighting
        [
          "hl", "hl.method", "hl.fl", "hl.usePhraseHighlighter", "hl.snippets",
          "hl.encoder", "hl.maxAnalyzedChars", "hl.bs.type",
          "hl.fragsize", "hl.fragsizeIsMinimum"
        ],

        # Also think we don't need these:
        ["facet", "facet.field", "facet.query"],
      ].flatten!
    end
  end
end
