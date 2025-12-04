# frozen_string_literal: true
#
# TODO: chf_sufia mixin's or equivalents for:
# * SearchBuilder::RestrictAdminSearchFields => Makes sure admin notes are only searchable if logged in
# * SearchBuilder::SyntheticCategoryLimit => something with making our 'topics'/synthetic categories
#   work as limits, probably just for showing the main page for a 'topic'
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior
  include BlacklightRangeLimit::RangeLimitBuilder


  # Scihist SearchBuilder extensions
  include SearchBuilder::AccessControlFilter
  include SearchBuilder::AdminOnlySearchFields
  include SearchBuilder::CustomSortLogic
  include SearchBuilder::AllSearchResultIdsBuilder

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

  ##
  # @example Adding a new step to the processor chain
  #   self.default_processor_chain += [:add_custom_data_to_query]
  #
  #   def add_custom_data_to_query(solr_parameters)
  #     solr_parameters[:custom] = blacklight_params[:user_value]
  #   end
end
