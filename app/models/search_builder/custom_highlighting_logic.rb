class SearchBuilder
  module CustomHighlightingLogic
    extend ActiveSupport::Concern


    ENGLISH_FILTER = Stopwords::Snowball::Filter.new("en")
    GERMAN_FILTER =   Stopwords::Snowball::Filter.new("de")

    included do
      self.default_processor_chain += [:custom_highlighting_logic]
    end

    def custom_highlighting_logic(solr_parameters)
      return if solr_parameters['q'].nil?
      solr_parameters['hl.q'] = (ENGLISH_FILTER.filter solr_parameters['q'].split).join(' ').strip
      solr_parameters[:"hl.q"] = (ENGLISH_FILTER.filter solr_parameters['q'].split).join(' ').strip
    end
  end
end

