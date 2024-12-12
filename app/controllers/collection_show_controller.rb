# Controller for public individual collection 'show' page.
#
# It's in it's own controller just for that, so it can inherit CatalogController
# for properly configured Blacklight search behavior.
#
# For that reason, the action for showing an individual collection is #index, so
# we can easily use built-in Blacklight search behavior and search views (facets etc).
# There may be a less hacky way to do this, esp in Blacklight 7, but this is a port of
# what was in chf_sufia. There also may not be.
class CollectionShowController < CatalogController
  before_action :collection, :check_auth

  ORAL_HISTORY_DEPARTMENT_VALUE = "Center for Oral History"

  def index
    if params[:box_id].present? && params[:box_id].chomp.match(/^[\d]+$/).nil?
      flash[:alert] = "Sorry, the box number should contain only digits."
      params[:box_id] = nil
    end
    if params[:folder_id].present?
      if params[:folder_id].chomp.match(/^[\d]+$/).nil?
        flash[:alert] = "Sorry, the box and folder numbers should contain only digits."
        params[:folder_id] = nil
      end
      if params[:box_id].nil? || params[:box_id].empty?
        flash[:alert] = "If you specify a folder, please also specify a box."
        params[:box_id] = nil
        params[:folder_id] = nil
      end
    end
    super
    @collection_opac_urls = CollectionOpacUrls.new(collection)
    @related_link_filter ||= RelatedLinkFilter.new(collection.related_link)
  end

  # This method can be overridden from blacklight to provide *dynamic* blacklight
  # config
  def blacklight_config
    # While the main Oral History collection gets it's own custom controller,
    # with it's own config and templates --  we have sub-collections that get
    # this generic controller.  If we have one here, use the config from that
    # main OH Controller, to get OH-customized facets and any other search config.
    if collection.department == ORAL_HISTORY_DEPARTMENT_VALUE
      CollectionShowControllers::OralHistoryCollectionController.blacklight_config
    else
      super
    end
  end

  configure_blacklight do |config|
    # Our custom sub-class to limit just to docs in collection, with collection id
    # taken from params[:collection_id]
    config.search_builder_class = ::SearchBuilder::WithinCollectionBuilder

    # and we need to make sure collection_id is allowed by BL, don't totally
    # understand this, as of BL 7.25
    config.search_state_fields << :collection_id
    config.search_state_fields << :box_id
    config.search_state_fields << :folder_id


    config.add_sort_field("box_folder") do |field|
      field.label = "box and folder"
      field.sort = "box_isim asc, folder_isim asc"
    end

  end

  private

  # Our custom SearchBuilder needs to know:
  #   collection id (UUID)
  #   the default sort order for this collection, if specified.
  def search_service_context
    super.merge!(collection_id: collection.id, collection_default_sort_order: collection_default_sort_order, box_id: params[:box_id], folder_id: params[:folder_id])
  end

  # Some collections define a default sort field. Look up its sort order in blacklight_config and use that.
  def collection_default_sort_order
    blacklight_config.sort_fields.dig(collection&.default_sort_field)&.sort
  end

  def check_auth
    authorize! :read, @collection
  end

  def collection
    @collection ||= Collection.find_by_friendlier_id!(params[:collection_id])
  end
  helper_method :collection
end
