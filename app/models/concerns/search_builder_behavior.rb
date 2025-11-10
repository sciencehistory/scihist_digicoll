# Blacklight 9 requires all local custom SearchBuilder logic to be duplicated in two
# places, also into a corresponding FacetSearchBuilder class. So we do it here, so
# it can be done in two places DRY.  Sorry for increase of complexity.
#
# See https://github.com/projectblacklight/blacklight/pull/3762
module SearchBuilderBehavior
  extend ActiveSupport::Concern

  # For blacklight_range_limit plugin
  include BlacklightRangeLimit::RangeLimitBuilder

  # Scihist SearchBuilder extensions
  include SearchBuilder::AccessControlFilter
  include SearchBuilder::AdminOnlySearchFields
  include SearchBuilder::CustomSortLogic
  include SearchBuilder::AllSearchResultIdsBuilder

  ##
  # @example Adding a new step to the processor chain
  #
  #   included do
  #     self.default_processor_chain += [:add_custom_data_to_query]
  #   end
  #
  #   def add_custom_data_to_query(solr_parameters)
  #     solr_parameters[:custom] = blacklight_params[:user_value]
  #   end
end
