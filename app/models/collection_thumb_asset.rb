class CollectionThumbAsset < Asset
  COLLECTION_PAGE_THUMB_SIZE = 266

  define_derivative("thumb_collection_page", content_type: "image") do |original_file|
    Kithe::VipsCliImageToJpeg.new(max_width: COLLECTION_PAGE_THUMB_SIZE, thumbnail_mode: true).call(original_file)
  end

  define_derivative("thumb_collection_page_2X", content_type: "image") do |original_file|
    Kithe::VipsCliImageToJpeg.new(max_width: COLLECTION_PAGE_THUMB_SIZE * 2, thumbnail_mode: true).call(original_file)
  end

end
