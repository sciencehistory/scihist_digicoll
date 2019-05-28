class CollectionResultDisplay < ViewModel
  def display
    render "/presenters/index_result", model: model, view: self
  end

  # TODO, link to Collections page, when it exists
  def display_genres
    ["Collection"]
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

end
