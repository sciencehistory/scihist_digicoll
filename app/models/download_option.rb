# frozen_string_literal: true

# A simple value object representing a download option, used for constructing our download
# menus
class DownloadOption
  attr_reader :label, :subhead, :url, :analyticsAction, :data_attrs, :work_friendlier_id, :content_type


  # Create a DownloadOption for one of our on-demand derivatives, DRY it up here
  # so we can re-use equivalently.
  def self.for_on_demand_derivative(label:, derivative_type:, work_friendlier_id:, subhead:nil)
    derivative_type = derivative_type.to_s

    unless derivative_type.in?(["pdf_file", "zip_file"])
      raise ArgumentError.new("derivative_type `#{derivative_type}` must be one of pdf_file or zip_file")
    end

    analytics_action = {
      "pdf_file" => "download_pdf",
      "zip_file" => "download_zip"
    }[derivative_type]

    content_type = {
      "pdf_file" => "application/pdf",
      "zip_file" => "application/zip"
    }[derivative_type]

    # defaults\
    subhead ||= {
     "pdf_file" => nil,
      "zip_file" => "of full-sized JPGs"
    }[derivative_type]

    DownloadOption.new(label, url: "#", analyticsAction: analytics_action,
      work_friendlier_id: work_friendlier_id,
      subhead: subhead,
      content_type: content_type,
      data_attrs: {
        trigger: "on-demand-download",
        derivative_type: derivative_type,
        work_id: work_friendlier_id
      }
    )
  end

  # Formats the sub-head for you, in a standard way, using info about the asset. If you don't
  # want this standard format, just use the ordinary new/initialize instead.
  #
  # If you don't want a given asset metadata item to be included in subhead, don't pass it
  # in to this method!
  #
  # @param label [String] main label for the download link
  # @param url [String] the url to link to
  # @param analyticsAction [String] a key to record in our analytics logging, up to caller
  #   to decide what to do with it, but probably will turn into a data- attribute for JS.
  # @param width [#to_s] number representing width dimension
  # @param height [#to_s] number representing height dimension
  # @param size [#to_i] number representing size in bytes
  # @param content_type[#to_s] mime/IANA media/content type like "image/jpeg"
  # @param data_attrs[Hash] hash compatible with rails content_tag `data:` argument, for additional data attributes
  #   to add to link.
  # @param work_friendlier_id [String] used for analytics data attributes
  # @param content_type [String] MIME/IANA content-type, sometimes used for icons and such on display
  def self.with_formatted_subhead(label, url:, work_friendlier_id:, analyticsAction:nil, width: nil, height: nil, size: nil, content_type: nil, download_url: nil)
    parts = []
    parts << ScihistDigicoll::Util.humanized_content_type(content_type) if content_type.present?
    parts << "#{width.to_s} x #{height.to_s}px" if width.present? && height.present?

    # translate bytes to KB or MB or GB etc.
    parts << ScihistDigicoll::Util.simple_bytes_to_human_string(size) if size.present?

    subhead = parts.join(" — ") # em-dash

    new(label, url: url, work_friendlier_id: work_friendlier_id, analyticsAction: analyticsAction, subhead: subhead.presence, download_url: download_url)
  end

  # @param label [String] main label for the download link
  # @param work_friendlier_id [String] used for analytics data attributes
  # @param url [String] the url to link to
  # @param subhead [String] a subheading/hint/more info for the label for the download link
  # @param analyticsAction [String] a key to record in our analytics logging, up to caller
  #   to decide what to do with it, but probably will turn into a data- attribute for JS.
  # @param download_url [String] some options have a separate "force download" URL, when the main url is viewed inline.
  #    Some of our UI offers both options. Optionally provide an alternate force download url.
  def initialize(label, url:, work_friendlier_id:, subhead:nil, analyticsAction:nil, content_type: nil, data_attrs: {}, download_url: nil)
    @label = label
    @subhead = subhead
    @url = url
    @analyticsAction = analyticsAction
    @data_attrs = data_attrs
    @work_friendlier_id = work_friendlier_id
    @content_type = content_type
    @download_url = download_url

    # Add in analytics data- attributes
    @data_attrs.merge!(analytics_data_attributes)

    # Sneakily add in data-turnstile-protection-true for originals that aren't PDFs
    if @analyticsAction == "download_original" && @content_type != "application/pdf" && ScihistDigicoll::Env.lookup(:cf_turnstile_downloads_enabled)
      @data_attrs.merge!({turnstile_protection: "true"})
    end
  end

  # trigger analytics JS, eg Google Analytics prob
  def analytics_data_attributes
    return {} unless work_friendlier_id
    {
      analytics_category: "Work",
      analytics_action: analyticsAction,
      analytics_label: work_friendlier_id
    }
  end

  # Rails architecture gives us #to_json for a string if we provide as_json
  def as_json(options={})
    {
      url: url,
      label: label,
      subhead: subhead,
      analyticsAction: analyticsAction
    }
  end

  # Some of our UI offers a main link to view inline, and a download link to force download.
  #
  # If we have an alternate download_url great, if not just use the main url here
  def download_url
    @download_url.presence || url
  end


  # sometimes we want to modify one, treat as immutable but let modify like this!
  # Can override any element as if it were initializer
  def dup_with(label=self.label, url: self.url, work_friendlier_id: self.work_friendlier_id, subhead:self.subhead, analyticsAction:self.analyticsAction, data_attrs: self.data_attrs, content_type: self.content_type, download_url: self.download_url)
    self.class.new(label, url: url, work_friendlier_id: work_friendlier_id, subhead:subhead, analyticsAction:analyticsAction, data_attrs: data_attrs, content_type: content_type, download_url: download_url)
  end
end
