# Some static utilty methods for creating filenames for downloads,
# usually to supply in content-disposition headers.
#
# In chf_sufia, this stuff all became a tangled mess. To try to avoid that,
# we're doing some kind of low-level non-OO utility methods for key parts, that
# can be mixed and matched and put together by other code. This might be
# better with a more OO API, but I didn't trust myself to get it right, start
# out like this!
class DownloadFilenameHelper

  # The actual content-disposition filename we want for a given asset -- and optionally
  # a given derivative.
  #
  # Can do different things for different sorts of Assets, like speical audio file
  # handling.
  def self.filename_for_asset(asset, derivative: nil)
    # audio files use their whole title instead of parents, with the intended
    # use case of Oral History, our only audio files at present, where archival
    # title is important.
    base = if asset.content_type && asset.content_type.start_with?("audio/")
      asset.title
    else
      DownloadFilenameHelper.filename_base_from_parent(asset)
    end

    if derivative && !asset.content_type.start_with?("audio")
      base = [base, derivative.key].join("_")
    end

    content_type = if derivative
      derivative.content_type
    else
      asset.content_type
    end

    DownloadFilenameHelper.filename_with_suffix(base, content_type: content_type)
  end

  # Pass in a string, get the first three words separated by underscores, stripping punctuation.
  # Ignores any filename dot-suffix. Downcases.
  #
  # Limits to 25 characters total.
  def self.first_three_words(str)
    # Not well documented, but it works:
    without_suffix = File.basename(str, ".*")

    without_suffix.gsub(/[']/, '').gsub(/([[:space:]]|[[:punct:]])+/, ' ').split.slice(0..2).join('_').downcase[0..24]
  end

  # Creates a download filename base (not including suffix) based on the parent title.
  # This is what we ordinarily use for original and derivative downloads names, with some
  # exceptions for special file types like Oral History audio.
  #
  # Finds parent of the asset, and takes first three words.
  # Combines with id of parent (for uniqueness), position of asset in parent (for ordering), and id of asset
  # (for identification).
  #
  #
  # Optionally pass in a content_type (eg "image/jpeg"), will be used for filename dot-suffix. Otherwise
  # filename dot-suffix from asset original type will be used if available.
  def self.filename_base_from_parent(asset)
    base = [
      (first_three_words(asset.parent.title) if asset.parent),
      (asset.parent.friendlier_id if asset.parent),
      (asset.position if asset.position.present?),
      asset.friendlier_id
    ].compact.join("_")
  end

  # Takes a base, and combines it with a filename dot-suffix, replacing
  # existing suffix if needed.
  #
  # The base should already be prepared for what you want -- the only thing
  # we'll do to it is a failsafe removal of characters no good for filenames (slash, backslash, colon).
  #
  # You can pass in a suffix literal like "jpg", or a content_type like "image/jpeg"
  # and we'll look up the suffix, or an Asset instance, and we'll look up the suffix
  # from it's content_type. precedence is suffix, content_type, and asset.content_type
  # in that order. You can pass in multiple, if some end up blank, it'll go on to try the
  # next.
  #
  # @param base [String] base filename, is left alone except filename-dangerous characters are removed.
  # @param suffix [String] eg "jpg"
  # @param content_type [String] eg "image/jpeg"
  # @param asset [Asset] will look up .content_type from asset, and suffix from that content_type.
  def self.filename_with_suffix(base, asset: nil, content_type: nil, suffix: nil)
    base = base.gsub(/[:\\\/]+/, '')

    if suffix.blank? && content_type.present?
      suffix = suffix_for_content_type(content_type)
    end

    if suffix.blank? && asset.present? && asset.content_type.present?
      suffix = suffix_for_content_type(asset.content_type)
    end

    if suffix.present?
      suffix = ".#{suffix}" unless suffix.start_with?('.')
      Pathname.new(base).sub_ext(suffix).to_s
    else
      # remove any existing suffix, the one that's there is not right but
      # we have no new one
      Pathname.new(base).sub_ext("").to_s
    end
  end

  # We'll try to find a suffix for a MIME type, first using rails Mime::Type
  # (types usually reigstered in config/initializers/mime_types.rb), then if
  # not found, using the mini_mime gem.
  #
  # Sometimes the 'official' suffix is not what we really want (mpga instead of mp3),
  # registering a mime-type with Rails initializers/mime_type.rb is the way to force it.
  def self.suffix_for_content_type(content_type)
    return "" unless content_type.present?

    mime_obj = Mime::Type.lookup(content_type)
    if mime_obj && mime_obj.symbol
      return mime_obj.symbol.to_s.downcase
    end

    MiniMime.lookup_by_content_type(content_type)&.extension
  end
end
