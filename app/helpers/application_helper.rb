module ApplicationHelper

  # What we show next to things that are not published, currently used
  # in management screens and possibly end-user front-end (although only managers,
  # if anyone, can see non-public things in end-user front-end).
  def publication_badge(kithe_model)
    unless kithe_model.published?
      '<span class="badge badge-warning">Private</span>'.html_safe
    end
  end

  def construct_page_title(title)
    "#{title} - #{application_name}"
  end

  # qa (questioning_authoriry) gem oddly gives us no route helpers, so
  # let's make one ourselves, for it's current mount point, we can change
  # it if needed but at least it's DRY.
  def qa_search_vocab_path(vocab, subauthority = nil)
    path = "/authorities/search/#{CGI.escape vocab}"

    if subauthority
      path += "/#{CGI.escape subauthority}"
    end

    path
  end

  def visibility_facet_labels(value)
    case value.to_s
    when "true" ; "published"
    when "false" ; "private"
    else ; value
    end
  end

  # delegating to current_policy, just as a convenience available as a helper too
  def can_see_unpublished_records?
    current_policy.can_see_unpublished_records?
  end

  # used on collection show pages, eg
  #
  # If we visit this page with no search criteria, we get a lot of info about the collection at
  # top, but if we have any search criteria at all OR have paginated, we have a much smaller
  # header
  def has_deeper_search?
    has_search_parameters? || (params[:page].present? && params[:page] != "1")
  end
end
