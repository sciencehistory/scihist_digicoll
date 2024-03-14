# Json-compat hash serializer for info for Internet Archive BookREader
# Returned by an HTTP endpoint for viewer.
#
#     BookReaderDataSerializer.new(work).as_array
#
#
class BookReaderDataSerializer
  INCLUDABLE_IMAGE_TYPES = ["image/jpeg", "image/png"]

  attr_reader :work, :show_unpublished

  def initialize(work, show_unpublished: false)
    @work = work
    @show_unpublished = show_unpublished
  end

  def as_array
    pairs_of_images(
      included_image_assets.enum_for(:each_with_index).collect do |asset, i|
        {
          # these may not actually be used by BookReader, but seems good to supply anyway
          # for sanity
          index: i + 1,
          title: asset.title,
          assetId: asset.friendlier_id,

          # These are used/needed by book reader
          height: asset.height,
          width: asset.width,
          dpi: asset.file_metadata["dpi"],

          # And our book reader code for now takes ALL available image derivatives,
          # in a custom key supplied by us, to have custom JS that will
          # try to supply best fit for what BookReader wants to display
          #
          img_by_width: available_img_derivative_urls_by_width(asset)
        }
      end
    )
  end

  private

  # Leaf representative only for any child work. images only.
  def included_image_assets
    @included_image_assets ||= begin
      members = work.members.order(:position)
      members = members.where(published: true) unless show_unpublished
      members.includes(:leaf_representative).select do |member|
        member.leaf_representative &&
        member.leaf_representative.content_type&.start_with?("image/") &&
        member.leaf_representative.stored?
      end.collect(&:leaf_representative)
    end
  end

  # BookReader wants images in duple array of two elements, each where
  # they are supposed to be facing pages. We don't have metadata to know
  # what pages are actually facing. For now we will assume first page is cover,
  # followed by [2,3] recto/verso, etc.
  def pairs_of_images(list)
    first = list.shift

    [ [first] ] + list.each_slice(2).to_a
  end

  # @return a hash of image width and url, for any acceptable image derivative found
  #   urls will be direct S3 urls?  So may be time-limited not cacheable, if private storage?
  def available_img_derivative_urls_by_width(asset)
    asset.file_derivatives.collect do |deriv_key, derivative_file|
      if derivative_file["mime_type"].in?(INCLUDABLE_IMAGE_TYPES) && derivative_file.width.present?
        [derivative_file.width, derivative_file.url]
      end
    end.compact.sort.to_h
  end
end
