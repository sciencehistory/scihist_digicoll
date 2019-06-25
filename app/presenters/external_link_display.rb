# How we display related_urls, a link
# Takes a String URL
#
#     UrlDisplay.new("https://example.com/foo/bar").display
#
class ExternalLinkDisplay < ViewModel
  valid_model_type_names "String"

  alias_method :url, :model

  def display
    link_to("<i class='fa fa-external-link'></i>&nbsp;".html_safe + abbreviated_value(url), url, target: "_blank")
  end

  private

  # Just the hostname
  def abbreviated_value(v)
    v =~ %r{https?\://([^/]+)}
    "#{$1}/…"
  end
end
