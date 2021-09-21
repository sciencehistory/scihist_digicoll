# Displays an element in search results for a "Work"
#
# * requires a ChildCountDisplayFetcher for efficient fetching and provision of "N Items"
# child count on display.
class CollectionResultDisplay < ResultDisplay
  valid_model_type_names "Collection"

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
    render ThumbComponent.new(model.leaf_representative, placeholder_img_url: asset_path("default_collection.svg"))
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

end
