module ApplicationHelper

  # What we show next to things that are not published, currently used
  # in management screens and possibly end-user front-end (although only managers,
  # if anyone, can see non-public things in end-user front-end).
  def publication_badge(kithe_model)
    unless kithe_model.published?
      '<span class="badge badge-warning">Private</span>'.html_safe
    end
  end
end
