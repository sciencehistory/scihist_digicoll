class SearchBuilder
  # An extension to Blacklight's SearchBuilder (which is locally generated in our app), such
  # that a "filter_public_domain=1" variable in app query params is translated to restricting
  # to just public domain items.
  module PublicDomainFilter
    extend ActiveSupport::Concern

    included do
      self.default_processor_chain += [:public_domain_filter]
    end

    def public_domain_filter(solr_params)
      # look for the public domain only checkbox
      if SearchBuilder::PublicDomainFilter.filtered_public_domain?(blacklight_params)
        solr_params[:fq] ||= []
        public_domain_filter = "{!term f=rights_facet}http://creativecommons.org/publicdomain/mark/1.0/"
        solr_params[:fq] << public_domain_filter
      end
    end

    def self.filtered_public_domain?(lparams)
      lparams.fetch("filter_public_domain", 0).to_i > 0
    end

  end
end
