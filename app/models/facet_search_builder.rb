class FacetSearchBuilder < Blacklight::FacetSearchBuilder
  include Blacklight::Solr::FacetSearchBuilderBehavior

  # shared logic with SearchBuilder that MUST be duplciated to avoid
  # subtle faulty behavior, see https://github.com/projectblacklight/blacklight/pull/3762
  include SearchBuilderBehavior


  # override from blacklight to change facet search behavior:
  #   1. normalize Unicode
  #   2. use solr regex search to anchor to beginning of words
  #
  # Copied/pasted/customized from:
  # https://github.com/projectblacklight/blacklight/blob/8c1d0e172dc03c7183a591bb9779794d23c85cc1/lib/blacklight/solr/facet_search_builder_behavior.rb#L56-L60
  def add_facet_suggestion_parameters(solr_params)
    return if facet.blank? || facet_suggestion_query.blank?

    query = facet_suggestion_query.unicode_normalize(:nfc)[0..50]

    # This will be executed as a Java regex, but Ruby regex escape should
    # be same thing.  (?i) == case insensitive flag.
    solr_params[:'facet.matches'] = "(?i).*\\b#{Regexp.escape query}.*"

    #solr_params[:'facet.contains'] = facet_suggestion_query[0..50]
    #solr_params[:'facet.contains.ignoreCase'] = true
  end

end
