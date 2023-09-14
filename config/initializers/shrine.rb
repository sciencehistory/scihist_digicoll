require 'shrine'


# Used for "direct uploads" from Javascript in form, sending them to OUR APP
# (rather than direct to S3)
Shrine.plugin :upload_endpoint

# For direct to s3 uploads
Shrine.plugin :uppy_s3_multipart

# For efficient re-use of single downloded copy for multiple metadata and before_promotion
# blocks. https://github.com/sciencehistory/kithe/pull/167
Shrine.plugin :tempfile

Shrine.storages = {
  cache: ScihistDigicoll::Env.shrine_cache_storage,
  store: ScihistDigicoll::Env.shrine_store_storage,
  video_store: ScihistDigicoll::Env.shrine_store_video_storage,
  video_derivatives: ScihistDigicoll::Env.shrine_video_derivatives_storage,
  kithe_derivatives: ScihistDigicoll::Env.shrine_derivatives_storage,
  restricted_kithe_derivatives: ScihistDigicoll::Env.shrine_restricted_derivatives_storage,
  on_demand_derivatives: ScihistDigicoll::Env.shrine_on_demand_derivatives_storage,
  combined_audio_derivatives: ScihistDigicoll::Env.shrine_combined_audio_derivatives_storage,
  dzi_storage: ScihistDigicoll::Env.shrine_dzi_storage
}
