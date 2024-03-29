# Produces metadata needed for opengraph share tags, and other social media sharing
# APIs, to describe a work.
#
#     attributes = WorkSocialShareAttributes.new(work, view_context: self)
#     attributes.page_title
#     attributes.simple_title
#     attributes.share_url
#     attributes.share_media_url
#     # etc
#
# The view_context is unfortunate -- if in a Rails view template, `self` will suffice, if
# in a controller the method `view_context` works -- it turns out there are too many things
# we need to create this metadata that are difficult without a Rails view_context. Including
# using our existing Rails helpers, using Rails' helpers for rails static asset urls, etc.
#
# Used in SocialShareDisply, and also our meta tags that are picked up by social media sites
# and others.
#
class WorkSocialShareAttributes
  attr_reader :work, :view_context

  delegate :content_for, :construct_page_title, :main_app, :asset_url, :work_url,
    to: :view_context

  def initialize(work, view_context:)
    @work = work
    @view_context = view_context
  end

  def call
    raise "This object does not actually support rendering"
  end

  def page_title
    @page_title ||= content_for(:page_title) || construct_page_title(work.title)
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
    elsif work.is_oral_history?
      # if no representative, give em the generic OH thumb
      asset_url("scihist_oral_histories_thumb.jpg")
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

  # social media sites want a fairly big thumb if possible. Faccebook recommends 1200x630.
  # https://developers.facebook.com/docs/sharing/webmasters/images/
  #
  # But if we only have smaller available (say for videos), we'll use that.
  def share_representative_derivative
    @share_representative_deriative ||= work&.leaf_representative&.file_derivatives&.dig(:download_medium) ||
      work&.leaf_representative&.file_derivatives&.dig(:download_small) ||
      work&.leaf_representative&.file_derivatives&.dig(:thumb_large_2x) ||
      work&.leaf_representative&.file_derivatives&.dig(:thumb_large)
  end

end
