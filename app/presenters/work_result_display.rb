class WorkResultDisplay < ViewModel
  valid_model_type_names "Work"

  delegate :additional_title

  def display
    render "/presenters/index_result", model: model, view: self
  end

  def display_genres
    @display_genres ||= safe_join(
      model.genre.map { |g| link_to g, search_on_facet_path(:genre_facet, g) },
      ", "
    )
  end

  def display_dates
    @display_dates = DateDisplayFormatter.new(model.date_of_work).display_dates
  end

  def link_to_href
    work_path(model)
  end

  # An array of elements for "part of" listing, includes 'parent' in a link,
  # or "source" in italics
  def part_of_elements
    @part_of_elements ||= [].tap do |arr|
      if model.parent.present?
        arr << link_to(model.parent.title, work_path(model.parent))
      end
      if model.source.present?
        arr << content_tag("i", model.source)
      end
    end
  end
end
