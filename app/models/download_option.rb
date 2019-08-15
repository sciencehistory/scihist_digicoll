# A simple value object representing a download option, used for constructing our download
# menus
class DownloadOption
  attr_reader :label, :subhead, :url, :analyticsAction, :data_attrs

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
  def self.with_formatted_subhead(label, url:, analyticsAction:nil, width: nil, height: nil, size: nil, content_type: nil)
    parts = []
    parts << ScihistDigicoll::Util.humanized_content_type(content_type) if content_type.present?
    parts << "#{width.to_s} x #{height.to_s}px" if width.present? && height.present?

    # Rails 'number_to_human_size' is actually specifically for computer storage unit size,
    # translates to KB or MB or GB etc.
    parts << ActiveSupport::NumberHelper.number_to_human_size(size) if size.present?

    subhead = parts.join(" — ") # em-dash

    new(label, url: url, analyticsAction: analyticsAction, subhead: subhead.presence)
  end

  # @param label [String] main label for the download link
  # @param subhead [String] a subheading/hint/more info for the label for the download link
  # @param url [String] the url to link to
  # @param analyticsAction [String] a key to record in our analytics logging, up to caller
  #   to decide what to do with it, but probably will turn into a data- attribute for JS.
  def initialize(label, url:, subhead:nil, analyticsAction:nil, data_attrs: {})
    @label = label
    @subhead = subhead
    @url = url
    @analyticsAction = analyticsAction
    @data_attrs = data_attrs
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
end
