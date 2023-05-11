class SearchBuilder
  # An extension to Blacklight's SearchBuilder (which is locally generated in our app), such
  # that a "filter_public_domain=1" variable in app query params is translated to restricting
  # to just public domain items.
  module PublicDomainFilter
    extend ActiveSupport::Concern

    included do
      self.default_processor_chain += [:public_domain_filter]
    end


    #https://solr.apache.org/guide/6_6/other-parsers.html#OtherParsers-TermsQueryParser

    def public_domain_filter(solr_params)
      # For the purposes of search, we consider the following to meet the definition of "Copyright Free"
      # See https://github.com/sciencehistory/scihist_digicoll/issues/2125
      # See config/data/rights_terms.yml
      considered_copyright_free = [
        "http://creativecommons.org/publicdomain/mark/1.0/",
        "http://rightsstatements.org/vocab/NKC/1.0/",
        "http://rightsstatements.org/vocab/NoC-US/1.0/",
        "http://rightsstatements.org/vocab/NoC-OKLR/1.0/"
      ].join(",")

      # look for the public domain only checkbox
      if SearchBuilder::PublicDomainFilter.filtered_public_domain?(blacklight_params)
        solr_params[:fq] ||= []
        public_domain_filter = "{!terms f=rights_facet}#{considered_copyright_free}"
        solr_params[:fq] << public_domain_filter
      end
    end

    def self.filtered_public_domain?(lparams)
      lparams.fetch("filter_public_domain", 0).to_i > 0
    end

  end
end
