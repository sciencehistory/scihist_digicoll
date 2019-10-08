class OrphanS3Originals < OrphanS3Base

  def shrine_storage
    ScihistDigicoll::Env.shrine_store_storage
  end

  def extra_prefix
    "asset"
  end

end
