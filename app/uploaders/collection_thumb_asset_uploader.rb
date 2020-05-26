class CollectionThumbAssetUploader < AssetUploader
  COLLECTION_PAGE_THUMB_SIZE = 266

  # remove inherited derivatives we don't need for collections. Kind of bad OO
  # design maybe we should have an abstract asset superclass with ordinary and collection
  # asset both as sub-classes we don't need to do this, but it works for now.
  Attacher.remove_derivative_definition!(*Attacher.defined_derivative_keys.find_all { |key| key.start_with?("download_")})
  Attacher.remove_derivative_definition!(:thumb_large, :thumb_large_2X)

  Attacher.define_derivative("thumb_collection_page", content_type: "image") do |original_file|
    Kithe::VipsCliImageToJpeg.new(max_width: COLLECTION_PAGE_THUMB_SIZE, thumbnail_mode: true).call(original_file)
  end

  Attacher.define_derivative("thumb_collection_page_2X", content_type: "image") do |original_file|
    Kithe::VipsCliImageToJpeg.new(max_width: COLLECTION_PAGE_THUMB_SIZE * 2, thumbnail_mode: true).call(original_file)
  end

end
