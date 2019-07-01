# Displays our social media share buttons for a work
#
# http://sharingbuttons.io/ is a good place to get URL template formats for new plain static
# share buttons, and where these may have originated from, along with social-media-service-specific
# docs.
#
# Note that the page being shared also needs the proper meta tags (mostly opengraph related) for
# the social media sites to pick up good metadata!
class SocialShareDisplay < ViewModel
  valid_model_type_names "Work"

  alias_method :work, :model

  delegate :page_title, :share_url, :share_media_url, :short_plain_description,
           :title_plus_description, to: :share_attributes

  def display
    content_tag("div", class: "social-media") do
      safe_join([
        facebook_share_link,
        twitter_share_link,
        pinterest_share_link
      ])
    end
  end

  private

  def share_attributes
    @share_attributes ||= WorkSocialShareAttributes.new(work)
  end

  def facebook_share_link
    # window.open is needed so facebook has permission to close window after it's done, for better UI %>

    link_to "javascript:window.open('https://facebook.com/sharer/sharer.php?#{{u: share_url}.to_param}')",
        class: 'social-media-link facebook btn btn-brand-dark',
        target: '_blank',
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
end
