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
  include SearchBuilder::CustomHighlightingLogic

  ##
  # @example Adding a new step to the processor chain
  #   self.default_processor_chain += [:add_custom_data_to_query]
  #
  #   def add_custom_data_to_query(solr_parameters)
  #     solr_parameters[:custom] = blacklight_params[:user_value]
  #   end
end
