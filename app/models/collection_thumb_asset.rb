class CollectionThumbAsset < Asset
  COLLECTION_PAGE_THUMB_SIZE = CollectionThumbAssetUploader::COLLECTION_LIST_PAGE_THUMB_SIZE

  set_shrine_uploader(CollectionThumbAssetUploader)
end
