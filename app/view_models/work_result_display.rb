class WorkResultDisplay < ViewModel
  def display
    render "/view_models/index_result", model: model, view: self
  end

  def display_genres
    # TODO, probably a better Blacklight-provided method for generating the url?
    @display_genres ||= safe_join(
      model.genre.map { |g| link_to g, search_catalog_path(f: { genre_facet: [g] }) },
      ", "
    )
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

  # TODO, this needs to be shared with other places, move to helper? Unify with
  # existing helper in ApplicationHelper#publication_badge?
  def display_permission_badge
    unless model.published
      content_tag("small", class: "chf-results-list-item-permission") do
        "private"
      end
    end
  end


end
