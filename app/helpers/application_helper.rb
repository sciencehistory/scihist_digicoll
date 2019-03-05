module ApplicationHelper

  # What we show next to things that are not published, in management
  # interface.
  def publication_badge(kithe_model)
    unless kithe_model.published?
      '<span class="badge badge-warning">Private</span>'.html_safe
    end
  end

end
