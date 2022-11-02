# Displays our social media share buttons for a work
#
# http://sharingbuttons.io/ is a good place to get URL template formats for new plain static
# share buttons, and where these may have originated from, along with social-media-service-specific
# docs.
#
# Note that the page being shared also needs the proper meta tags (mostly opengraph related) for
# the social media sites to pick up good metadata!
class SocialShareComponent < ApplicationComponent
  attr_reader :work

  delegate :page_title, :share_url, :share_media_url, :short_plain_description,
           :title_plus_description, to: :share_attributes

  def initialize(work)
    @work = work
  end

  def call
    content_tag("div", class: "social-media") do
      safe_join([
        facebook_share_link,
        twitter_share_link,
        pinterest_share_link,
        google_classroom_share_link
      ])
    end
  end

  private

  def share_attributes
    @share_attributes ||= WorkSocialShareAttributes.new(work, view_context: view_context)
  end

  def facebook_share_link
    # window.open is needed so facebook has permission to close window after it's done, for better UI %>

    link_to "javascript:window.open('https://facebook.com/sharer/sharer.php?#{{u: share_url}.to_param}')",
        class: 'social-media-link facebook btn btn-brand-dark',
        rel: 'noopener noreferrer',
        data: {
          analytics_category: "Work",
          analytics_action: "share_facebook",
          analytics_label: work.friendlier_id
        },
        "aria-label" => "Share to Facebook",
        title: "Share to Facebook" do
      '<i class="fa fa-facebook-f" aria-hidden="true"></i>'.html_safe
    end
  end

  def twitter_share_link
    # intentionally no text for twitter, cause title will show up in twitter card due to tags. user can enter own text %>
    link_to "https://twitter.com/intent/tweet/?#{{url: share_url}.to_param}",
        class: 'social-media-link twitter btn btn-brand-dark',
        target: '_blank',
        rel: 'noopener noreferrer',
        data: {
          analytics_category: "Work",
          analytics_action: "share_twitter",
          analytics_label: work.friendlier_id
        },
        "aria-label" => "Share to Twitter",
        title: "Share to Twitter" do
      '<i class="fa fa-twitter" aria-hidden="true"aria-hidden="true" ></i>'.html_safe
    end
  end

  # See  https://developers.pinterest.com/docs/widgets/save/?
  def pinterest_share_link
    link_to "https://pinterest.com/pin/create/button/?#{{url: share_url, media: share_media_url, description: title_plus_description}.to_param}",
        class: 'social-media-link pinterest btn btn-brand-dark',
        target: '_blank',
        rel: 'noopener noreferrer',
        data: {
          analytics_category: "Work",
          analytics_action: "share_pinterest",
          analytics_label: work.friendlier_id
        },
        "aria-label" => "Share to Pinterest",
        title: 'Share to Pinterest' do
    '<i class="fa fa-pinterest-p" aria-hidden="true"></i>'.html_safe
    end
  end

  # This was not getting served by cloudfront,
  # so I'm just adding it to an inline svg.
  # Also much easier to tweak; we can move it back to a file once
  # we have consensus on the design.
  def google_classroom_svg(alt, css_class)
    # discreet grey colors
    # color_scheme = { light: "#eee", dark: "#aaa"}

    # colors from: view-source:https://upload.wikimedia.org/wikipedia/commons/2/25/Google_Classroom_icon.svg
    color_scheme = { light: "#fff", dark: "#57BB8A"}

    "<svg alt=\"#{alt}\" class=\"#{css_class}\"
      viewBox=\"0 0 50 50\"
      xmlns=\"http://www.w3.org/2000/svg\"
      >

      <path d=\"M32 25a2.25 2.25 0 1 0 0-4.5 2.25 2.25 0 0 0 0
        4.5zm0 1.5c-2.41 0-5 1.277-5 2.858V31h10v-1.642c0-1.58-2.59-2.858-5-2.858zM16
        25a2.25 2.25 0 1 0 0-4.5 2.25 2.25 0 0 0 0
        4.5zm0 1.5c-2.41 0-5 1.277-5 2.858V31h10v-1.642c0-1.58-2.59-2.858-5-2.858z\"
        fill=\"#{color_scheme[:dark]}\" fill-rule=\"nonzero\" mask=\"url(#b)\"></path>

      <path d=\"M24.003 23A3 3 0 1 0 21 20c0 1.657 1.345 3
      3.003 3zM24 25c-3.375 0-7 1.79-7 4v2h14v-2c0-2.21-3.625-4-7-4z\"
      fill=\"#{color_scheme[:light]}\" fill-rule=\"nonzero\" mask=\"url(#b)\"></path>

    </svg>".html_safe
  end

  # Extra parameters are described at https://developers.google.com/classroom/guides/sharebutton .
  def google_classroom_share_link
    link_to "https://classroom.google.com/u/0/share?#{{url: share_url, title: page_title}.to_param}",
        class: 'social-media-link google_classroom btn',
        target: '_blank',
        rel: 'noopener noreferrer',
        data: {
          analytics_category: "Work",
          analytics_action: "share_google_classroom",
          analytics_label: work.friendlier_id
        },
        "aria-label" => "Share to Google Classroom",
        title: 'Share to Google Classroom' do
         google_classroom_svg('Share to Google Classroom', 'google-classroom-share-icon')
    end
  end
end
