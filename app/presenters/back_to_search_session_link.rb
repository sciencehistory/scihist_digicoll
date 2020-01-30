# We need this cause our 'show' controllers aren't blacklight controlleres, so we have to try
# to extract/reproduce blacklight's logic for figuring out the session-stored search context,
# and providing a link back to it.
#
# Possibly unlike the default BL behavior, we don't want to provide a 'back to search' link
# unless there is search context in session.
class BackToSearchSessionLink < ViewModel
  include Blacklight::SearchContext
  include Blacklight::UrlHelperBehavior

  def initialize()
    # We're using draper-based ViewModel for access to helper/controller context,
    # but don't actually have a model object, but draper requires one
    super("")
  end

  def display
    url = url_to_search_context
    if url
      link_to t('blacklight.back_to_search'), url_to_search_context
    end
  end

  # Based on Blacklight::UrlHelperBehavior#link_back_to_catalog but seriously
  # simplified with assumptions about our app
  def url_to_search_context
    return nil unless current_search_session

    query_params = current_search_session.query_params

    if search_session['counter']
      per_page = (search_session['per_page'] || blacklight_config.default_per_page).to_i
      counter = search_session['counter'].to_i

      query_params[:per_page] = per_page unless per_page.to_i == blacklight_config.default_per_page
      query_params[:page] = ((counter - 1) / per_page) + 1
    end

    if query_params.blank?
      catalog_search_path
    else
      url_for(query_params)
    end
  end

  # Blacklight modules expect this, hard-code to CatalogController's class-level one, can
  # introduce bugs if controller thinks it's doing dynamic re-configuration or we use
  # other BL controllers.
  def blacklight_config
    CatalogController.blacklight_config
  end

  # Copied from Blacklight::Controller to pretend to be one enough for search context func.
  # Returns a list of Searches from the ids in the user's history.
  def searches_from_history
    session[:history].blank? ? ::Search.none : ::Search.where(id: session[:history]).order("updated_at desc")
  end
end
