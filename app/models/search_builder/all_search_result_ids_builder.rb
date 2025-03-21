class SearchBuilder

  module AllSearchResultIdsBuilder
    extend ActiveSupport::Concern

    included do
      self.default_processor_chain += [:all_search_result_ids_processor]
    end


    def all_search_result_ids_processor(solr_parameters)
      return unless scope.context[:all_search_result_ids] == 'true'
      unneeded_keys = []
      # Keep the sort for now
      # unneeded_keys << ['sort']
      # don't need facet limit keys
      unneeded_keys << solr_parameters.keys.select {|k| k.include? 'facet.limit'}
      #solr_parameters.except!(*facet_limit_keys)
      # don't need stats
      unneeded_keys << ["stats", "stats.field"]
      # don't need highlighting
      unneeded_keys <<  ["hl", "hl.method", "hl.fl", "hl.usePhraseHighlighter", "hl.snippets", "hl.encoder", "hl.maxAnalyzedChars", "hl.bs.type", "hl.fragsize", "hl.fragsizeIsMinimum"]
      # Also think we don't need these:
      unneeded_keys <<  ["facet", "facet.field", "facet.query"]

      unneeded_keys.flatten!
      solr_parameters.except!(*unneeded_keys)

      # return only ids, and return up to ten million of them.
      solr_parameters.merge!({fl:"id", rows: '10000000'})
    end
  end
end
