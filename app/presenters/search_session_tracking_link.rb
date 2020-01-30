# Prob only does anything sensible when called in a view from
# Blacklight CatalogController, and in fact we hard-code some assumptions that the class
# is `CatalogController` specifically.
#
class SearchSessionTrackingLink < ViewModel
  include Blacklight::SearchContext
  include Blacklight::UrlHelperBehavior

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
    return nil if model.nil? || !blacklight_config&.track_search_session

    track_catalog_path(model,
      per_page: params.fetch(:per_page, search_session['per_page']),
      counter: count_into_search_results,
      search_id: current_search_session.try(:id)
    )
  end

  # Based on Blacklight::CatalogHelperBehavior#document_counter_with_offset
  def count_into_search_results
    # SO hacky controller.instance_variable_get, but that's what we need to get.
    offset ||= controller.instance_variable_get("@response")&.start
    offset ||= 0

    index + 1 + offset
  end

  # Copied from Blacklight::Controller to pretend to be one enough for search context func.
  # Returns a list of Searches from the ids in the user's history.
  def searches_from_history
    session[:history].blank? ? ::Search.none : ::Search.where(id: session[:history]).order("updated_at desc")
  end

  # Copied from Blacklight::Controller to pretend to be one enough for search context func.
  #
  # @return [Blacklight::SearchState] a memoized instance of the parameter state.
  def search_state
    @search_state ||= CatalogController.search_state_class.new(params, blacklight_config, self)
  end

  # Blacklight modules expect this, hard-code to CatalogController's class-level one, can
  # introduce bugs if controller thinks it's doing dynamic re-configuration or we use
  # other BL controllers.
  def blacklight_config
    CatalogController.blacklight_config
  end

end
