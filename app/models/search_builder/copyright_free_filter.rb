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
      
      # look for the "Copyright Free" checkbox
      if SearchBuilder::CopyrightFreeFilter.filtered_copyright_free?(blacklight_params)
        solr_params[:fq] ||= []
        copyright_free_filter = "{!term f=rights_facet}Copyright Free"
        solr_params[:fq] << copyright_free_filter
      end
    end

    def self.filtered_copyright_free?(lparams)
      lparams.fetch("filter_copyright_free", 0).to_i > 0
    end

  end
end
