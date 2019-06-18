# Displays an element in search results for a "Work"
#
# * requires a ChildCountDisplayFetcher for efficient fetching and provision of "N Items"
# child count on display.
class CollectionResultDisplay < ViewModel
  valid_model_type_names "Collection"

  attr_reader :child_counter

  # @param collection [Collection]
  # @param child_counter [ChildCountDisplayFetcher]
  def initialize(collection, child_counter:)
    @child_counter = child_counter
    super(collection)
  end

  def display
    render "/presenters/index_result", model: model, view: self
  end

  # TODO, link to Collections page, when it exists
  def display_genres
    ["Collection"]
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

  # TODO, link to Collection detail page when it exists.
  def link_to_href
    "#"
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


end
