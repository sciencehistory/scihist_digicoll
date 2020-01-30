# Prob only does anything sensible when called in a view from
# Blacklight CatalogController, and in fact we hard-code some assumptions that the class
# is `CatalogController` specifically.
#
class SearchSessionTrackingLink < ViewModel
  attr_reader :index

  def initialize(model, index:)
    @index = index
    super(model)
  end

  # Based on internals of Blacklight::UrlHelperBehavior#session_tracking_params and #session_tracking_path
  # TODO link to in current BL version.
  #
  # Returns something like:
  #
  #     /catalog/[work_id, ignored]/track?counter=[one_based_index_in_results]&per_page=[current_per_page]&search_id=[current_search_id]
  def tracking_search_hit_link
    # this only works if it's a catalog controller!!
    if controller.kind_of?(Blacklight::Catalog)
      helpers.session_tracking_params(model, count_into_search_results).dig(:data, :"context-href")
    end
  end

  # Based on Blacklight::CatalogHelperBehavior#document_counter_with_offset
  def count_into_search_results
    # SO hacky controller.instance_variable_get, but that's what we need to get.
    offset ||= controller.instance_variable_get("@response")&.start
    offset ||= 0

    index + 1 + offset
  end
end
