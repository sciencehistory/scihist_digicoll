# This controller (just used for #index) runs a Blacklight search for all works and collections specified in the params,
# and returns JUST the friendlier ids in the search results, in a JSON array.
class AllSearchResultIdsController < CatalogController

  configure_blacklight do |config|
    config.search_state_fields << :all_search_result_ids
  end

  private

  def search_service_context
    super.merge!(all_search_result_ids: 'true')
  end

  # no need to bulk-load works
  self.search_service_class =  Blacklight::SearchService

private
  # override two methods in CatalogController that would otherwise prevent us from returning json results.
  def catch_bad_request_headers
  end

  def catch_bad_format_param
  end

end