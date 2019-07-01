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
        title: "Share to Facebook" do
      '<i class="fa fa-facebook-f"></i>'.html_safe
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
        title: "Share to Twitter" do
      '<i class="fa fa-twitter"></i>'.html_safe
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
        title: 'Share to Pinterest' do
    '<i class="fa fa-pinterest-p"></i>'.html_safe
    end
  end

  def page_title
    content_for(:page_title) || construct_page_title(work.title)
  end

  def share_url
    work_url(work)
  end

  # Our 'medium' downloadable derivative, at 1200px wide, is a good size for
  # social media share requirements. Various social media guidelines want
  # higher-res than you might expect.
  #
  # We are intentionally using the public direct S3 URL, to hopefully make it a persistent
  # and cacheable URL (unlike temporary signed URLs), which seems good for social media sites.
  # That does mean it has to be public ACL on S3.
  def share_media_url
    derivative = work&.leaf_representative&.derivative_for(:download_medium)
    if derivative
      url = derivative.url(public: true)

      # Make sure it's absolute not relative, for /public files instead of S3
      parsed = Addressable::URI.parse(url)
      if parsed.relative?
        url = Addressable::URI.parse(main_app.root_url).join(parsed)
      end

      url
    end
  end

  # we want it not escaped (cause we're gonna use it in a URL where it will get escaped at that point.)
  # But also NOT marked html_safe, because it's not!
  #
  # The truncate helper makes that hard, we have to embed it in a string literal to get it neither
  # escaped nor marked html_safe
  def short_plain_description
    return "" unless work.description.present?

    "#{truncate(
      strip_tags(work.description),
      escape: false,
      length: 400,
      separator: /\s/
    )}"
  end

  def title_plus_description
    short_plain_description.present? ? "#{page_title}: #{short_plain_description}" : page_title
  end
end
