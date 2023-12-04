# frozen_string_literal: true

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

  # See https://developers.google.com/classroom/guides/sharebutton
  def google_classroom_share_link
    link_to "https://classroom.google.com/u/0/share?#{{url: share_url, title: work.title}.to_param}",
      class: "social-media-link google_classroom btn btn-brand-dark",
      target: '_blank',
      rel: 'noopener noreferrer',
      data: {
        analytics_category: "Work",
        analytics_action: "share_google_classroom",
        analytics_label: work.friendlier_id
      },
      "aria-label" => "Share to Google Classroom",
      title: 'Share to Google Classroom' do
        google_classroom_svg('Share to Google Classroom', 'google-classroom-share-icon').html_safe
    end
  end

  def google_classroom_svg(alt, css_class)
    "<svg alt=\"#{alt}\" class=\"#{css_class}\"
      viewBox=\"9 10 30 30\"
      xmlns=\"http://www.w3.org/2000/svg\" >
      <path d=\"M32 25a2.25 2.25 0 1 0 0-4.5 2.25 2.25 0 0 0 0
        4.5zm0 1.5c-2.41 0-5 1.277-5 2.858V31h10v-1.642c0-1.58-2.59-2.858-5-2.858zM16
        25a2.25 2.25 0 1 0 0-4.5 2.25 2.25 0 0 0 0
        4.5zm0 1.5c-2.41 0-5 1.277-5 2.858V31h10v-1.642c0-1.58-2.59-2.858-5-2.858z\"
        fill=\"#aaa\" fill-rule=\"nonzero\" mask=\"url(#b)\"></path>
      <path d=\"M24.003 23A3 3 0 1 0 21 20c0 1.657 1.345 3
      3.003 3zM24 25c-3.375 0-7 1.79-7 4v2h14v-2c0-2.21-3.625-4-7-4z\"
      fill=\"#fff\" fill-rule=\"nonzero\" mask=\"url(#b)\"></path>
    </svg>"
  end
end
