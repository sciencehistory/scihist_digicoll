class CollectionResultDisplay < ViewModel
  def display
    render "/presenters/index_result", model: model, view: self
  end

  # TODO, link to Collections page, when it exists
  def display_genres
    ["Collection"]
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
