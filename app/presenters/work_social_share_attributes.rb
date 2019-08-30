# Get some things we need for social media metadata links and share links.
#
# Used in SocialShareDisply, and also our meta tags that are picked up by social media sites
# and others.
class WorkSocialShareAttributes < ViewModel
  valid_model_type_names "Work"

  alias_method :work, :model

  def page_title
    content_for(:page_title) || construct_page_title(work.title)
  end

  def simple_title
    work.title
  end

  def share_url
    work_url(work)
  end

  def rights_statement
    work.rights
  end

  # Our 'medium' downloadable derivative, at 1200px wide, is a good size for
  # social media share requirements. Various social media guidelines want
  # higher-res than you might expect.
  #
  # We are intentionally using the public direct S3 URL, to hopefully make it a persistent
  # and cacheable URL (unlike temporary signed URLs), which seems good for social media sites.
  # That does mean it has to be public ACL on S3.
  def share_media_url
    if share_representative_derivative
      url = share_representative_derivative.url(public: true)

      # Make sure it's absolute not relative, for /public files instead of S3
      parsed = Addressable::URI.parse(url)
      if parsed.relative?
        url = Addressable::URI.parse(main_app.root_url).join(parsed).to_s
      end

      url
    end
  end

  def share_media_height
    share_representative_derivative&.height
  end

  def share_media_width
    share_representative_derivative&.width
  end

  def short_plain_description
    DescriptionDisplayFormatter.new(work.description, truncate: 400).format_plain
  end

  def title_plus_description
    short_plain_description.present? ? "#{page_title}: #{short_plain_description}" : page_title
  end

  private

  def share_representative_derivative
    @share_representative_deriative ||= work&.leaf_representative&.derivative_for(:download_medium)
  end

end
