# Just a tiny component to standardize How we display related_urls, a link
# with a little external link icon.
#
# Takes a String URL
#
#     <%= render UrlDisplay.new("https://example.com/foo/bar") %>
#
class ExternalLinkComponent < ApplicationComponent
  attr_reader :url

  def initialize(url)
    @url = url
  end

  def call
    link_to("<i class='fa fa-external-link'></i>&nbsp;".html_safe + abbreviated_value(url), url, target: "_blank")
  end

  private

  # Just the hostname
  def abbreviated_value(v)
    v =~ %r{https?\://([^/]+)}
    "#{$1}/…"
  end
end
