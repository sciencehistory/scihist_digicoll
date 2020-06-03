# Displays an element in search results for a "Work"
#
# * requires a ChildCountDisplayFetcher for efficient fetching and provision of "N Items"
# child count on display.
class CollectionResultDisplay < ViewModel
  valid_model_type_names "Collection"

  attr_reader :child_counter, :solr_document

  # @param collection [Collection]
  # @param child_counter [ChildCountDisplayFetcher]
  # @param solr_document [SolrDocument] Blacklight SolrDocument with solr result into
  #
  # Ignore other params we don't care about, such as cart_presence
  def initialize(collection, child_counter:, solr_document:, **_unused_options)
    @child_counter = child_counter
    @solr_document = solr_document
    super(collection)
  end

  def display
    render "/presenters/index_result", model: model, view: self
  end

  def display_genres
    link_to "Collections", collections_path
  end

  # Requires helper method `child_counter` to be available, returning a
  # ChildCountDisplayFetcher. Provided by CatalogController.
  def display_num_children
    count = child_counter.display_count_for(model)
    return "" unless count > 0

    content_tag("div", class: "scihist-results-list-item-num-members") do
      number_with_delimiter(count) + ' item'.pluralize(count)
    end
  end

  def thumbnail_html
    ThumbDisplay.new(model.leaf_representative, placeholder_img_url: asset_path("default_collection.svg")).display
  end

  def link_to_href
    collection_path(model)
  end

  # none for collections
  def display_dates
    []
  end

  def additional_title
    []
  end

  def part_of_elements
    []
  end

  # we don't have any Collection result display at present
  def metadata_labels_and_values
    {}.freeze
  end

  def show_cart_control?
    false # never for collections
  end

  # results in context highlights from solr, if available
  # TODO this is copy pasted from work_result_display, we should have a common superclass or something?
  def search_highlights
    @search_highlights ||= begin
      highlights = solr_document.has_highlight_field?("searchabe_fultext") && solr_document.highlight_field("searchable_fulltext")
      if highlights
        safe_join(
        ["", *highlights, ""],
        "…")
      else
        ""
      end
    end
  end





end
