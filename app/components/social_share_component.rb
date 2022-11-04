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
    color_scheme = { light: "#fff", dark: "#aaa"}

    # colors from: view-source:https://upload.wikimedia.org/wikipedia/commons/2/25/Google_Classroom_icon.svg
    # color_scheme = { light: "#fff", dark: "#57BB8A"}

    "<svg alt=\"#{alt}\" class=\"#{css_class}\"
      viewBox=\"9 10 30 30\"
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

  # This was not getting served by cloudfront,
  # so I'm just adding it to an inline svg.
  # Also much easier to tweak; we can move it back to a file once
  # we have consensus on the design.
  #This is from https://dp.la/static/images/google-classroom.svg
  def rectangular_google_classroom_svg(alt, css_class)

    "<svg viewBox=\"0 0 36 31\"
    xmlns=\"http://www.w3.org/2000/svg\">
    <g fill=\"none\" fill-rule=\"evenodd\">
    <path d=\"M0-3h36v36H0z\"/><g fill-rule=\"nonzero\">
    <path d=\"M32.5714286 30.8571429H3.42857143C1.5377143 30.8571429 0 29.3194286
    0 27.4285714V3.42857143C0 1.5377143 1.5377143 0 3.42857143 0H32.5714286C34.4622857
    0 36 1.5377143 36 3.42857143V27.4285714c0 1.8908572-1.5377143
    3.4285715-3.4285714 3.4285715z\" fill=\"#989898\"/>
    <path fill=\"#000\" d=\"M3.42857143 3.42857143h29.1428571v24H3.42857143z\"/>
    <path fill=\"#FFF\" d=\"M21.4285714 25.7142857h6.85714286v1.7142857H21.4285714z\"/>
    <circle fill=\"#FFF\" cx=\"18\" cy=\"12\" r=\"2.57142857\"/>
    <circle fill=\"#888\" cx=\"11.1428571\" cy=\"14.5714286\" r=\"1.71428571\"/>
    <path fill=\"#777\" d=\"M28.2857143 27.4285714h-6.8571429l3.4285715 3.4285715h6.8571428\"/>
    <circle fill=\"#888\" cx=\"24.8571429\" cy=\"14.5714286\" r=\"1.71428571\"/>
    <path d=\"M29.1428571 19.4468571c0-.3814285-.1397142-.7491428-.4011428-1.0277142-.594-.6334286-1.8591429-1.2762858-3.8845714-1.2762858-2.0254286
    0-3.2905715.6428572-3.8845715 1.2762858-.2614285.2785714-.4011428.6454285-.4011428
    1.0277142v1.1245715h8.5714285v-1.1245715zM15.4285714
    19.4468571c0-.3814285-.1397143-.7491428-.4011428-1.0277142-.594-.6334286-1.8591429-1.2762858-3.8845715-1.2762858-2.02542853
    0-3.2905714.6428572-3.8845714 1.2762858-.26142856.2785714-.40114284.6454285-.40114284 1.0277142v1.1245715h8.57142854v-1.1245715z\" fill=\"#888\"/>
    <path d=\"M23.1428571 18.636c0-.4577143-.168-.8982857-.4817142-1.2325714C21.9488571
    16.6431429 20.43 15.4285714 18 15.4285714c-2.43 0-3.9488571 1.2145715-4.6611429
    1.974-.3137142.3342857-.4817142.7748572-.4817142 1.2334286v1.9354286h10.2857142V18.636z\" fill=\"#FFF\"/></g></g></svg>".html_safe
  end

  # Extra parameters are described at https://developers.google.com/classroom/guides/sharebutton .
  def google_classroom_share_link
    square = true

    extra_link_classes = square ? "google-classroom-square" : "google-classroom-round"

    svg = square ?
      rectangular_google_classroom_svg('Share to Google Classroom', 'google-classroom-share-icon') :
      google_classroom_svg('Share to Google Classroom', 'google-classroom-share-icon')

    link_to "https://classroom.google.com/u/0/share?#{{url: share_url, title: page_title}.to_param}",
        class: "social-media-link #{extra_link_classes} google_classroom btn",
        target: '_blank',
        rel: 'noopener noreferrer',
        data: {
          analytics_category: "Work",
          analytics_action: "share_google_classroom",
          analytics_label: work.friendlier_id
        },
        "aria-label" => "Share to Google Classroom",
        title: 'Share to Google Classroom' do
          svg
    end
  end
end
