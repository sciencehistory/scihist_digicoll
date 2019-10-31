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

  # for now any logged in user is a staff user
  def current_staff_user?
    current_user.present?
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

end
