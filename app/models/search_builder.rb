# frozen_string_literal: true
#
# TODO: chf_sufia mixin's or equivalents for:
# * SearchBuilder::RestrictAdminSearchFields => Makes sure admin notes are only searchable if logged in
# * SearchBuilder::PublicDomainFilter => makes the URL param put in by our "public domain only" checkbox
#   has an effect on search
# * SearchBuilder::SyntheticCategoryLimit => something with making our 'topics'/synthetic categories
#   work as limits, probably just for showing the main page for a 'topic'
class SearchBuilder < Blacklight::SearchBuilder
  include Blacklight::Solr::SearchBuilderBehavior

  # Scihist SearchBuilder extensions
  include SearchBuilder::AdminOnlySearchFields

  ##
  # @example Adding a new step to the processor chain
  #   self.default_processor_chain += [:add_custom_data_to_query]
  #
  #   def add_custom_data_to_query(solr_parameters)
  #     solr_parameters[:custom] = blacklight_params[:user_value]
  #   end
end
