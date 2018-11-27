require 'shrine'


# Used for "direct uploads" from Javascript in form, sending them to OUR APP
# (rather than direct to S3)
Shrine.plugin :upload_endpoint

# For direct to s3 uploads
Shrine.plugin :uppy_s3_multipart

Shrine.storages = {
  cache: ScihistDigicoll::Env.shrine_cache_storage,
  store: ScihistDigicoll::Env.shrine_store_storage,
}
