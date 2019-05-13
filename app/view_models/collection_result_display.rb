class CollectionResultDisplay < ViewModel
  def display
    render "/view_models/index_result", model: model, view: self
  end

  # TODO, link to Collections page, when it exists
  def display_genres
    ["Collection"]
  end

  # TODO, unify and eliminate from here
  def display_permission_badge
    ""
  end

  def additional_title
    []
  end

  def part_of_elements
    []
  end

end
