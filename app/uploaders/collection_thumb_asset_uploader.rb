class CollectionThumbAssetUploader < AssetUploader
  COLLECTION_LIST_PAGE_THUMB_SIZE = 266
  COLLECTION_SHOW_PAGE_THUMB_SIZE = 514

  # remove inherited derivatives we don't need for collections. Kind of bad OO
  # design maybe we should have an abstract asset superclass with ordinary and collection
  # asset both as sub-classes we don't need to do this, but it works for now.
  #
  # Should we actually be removing ALL derivatives defined in parent, so we don't forget
  # to add here when we add new ones to parent we don't want here? Do we want ANY of them?
  Attacher.remove_derivative_definition!(*Attacher.defined_derivative_keys.find_all { |key| key.start_with?("download_")})
  Attacher.remove_derivative_definition!(:thumb_large, :thumb_large_2X, :graphiconly_pdf)

  Attacher.define_derivative("thumb_collection_page", content_type: "image") do |original_file, add_metadata:|
    Kithe::VipsCliImageToJpeg.new(max_width: COLLECTION_LIST_PAGE_THUMB_SIZE, thumbnail_mode: true).call(original_file, add_metadata: add_metadata)
  end

  Attacher.define_derivative("thumb_collection_page_2X", content_type: "image") do |original_file, add_metadata:|
    Kithe::VipsCliImageToJpeg.new(max_width: COLLECTION_LIST_PAGE_THUMB_SIZE * 2, thumbnail_mode: true).call(original_file, add_metadata: add_metadata)
  end

  Attacher.define_derivative("thumb_collection_show_page", content_type: "image") do |original_file, add_metadata:|
    Kithe::VipsCliImageToJpeg.new(max_width: COLLECTION_SHOW_PAGE_THUMB_SIZE, thumbnail_mode: true).call(original_file, add_metadata: add_metadata)
  end

  Attacher.define_derivative("thumb_collection_show_page_2X", content_type: "image") do |original_file, add_metadata:|
    Kithe::VipsCliImageToJpeg.new(max_width: COLLECTION_SHOW_PAGE_THUMB_SIZE * 2, thumbnail_mode: true).call(original_file, add_metadata: add_metadata)
  end
end
