class SearchBuilder
  # An extension to Blacklight's SearchBuilder (which is locally generated in our app), such
  # that a "filter_copyright_free=1" variable in app query params is translated to restricting
  # to items that are free of copyright.
  module CopyrightFreeFilter
    extend ActiveSupport::Concern

    included do
      self.default_processor_chain += [:copyright_free_filter]
    end

    def copyright_free_filter(solr_params)
      # We consider these URIs "free of copyright" for the purposes of our search checkbox:
      uris_to_match = RightsTerm.copyright_free_filter_uris().join(",")
      
      # look for the "Copyright Free" checkbox
      if SearchBuilder::CopyrightFreeFilter.filtered_copyright_free?(blacklight_params)
        solr_params[:fq] ||= []
        # SOLR note:
        # The terms query parser "takes in multiple values separated by commas and returns documents matching any of the specified values."
        # https://solr.apache.org/guide/solr/latest/query-guide/other-parsers.html#terms-query-parser
        copyright_free_filter = "{!terms f=rights_facet}#{uris_to_match}"
        solr_params[:fq] << copyright_free_filter
      end
    end

    def self.filtered_copyright_free?(lparams)
      lparams.fetch("filter_copyright_free", 0).to_i > 0
    end

  end
end
