module UploadUtil
  def self.kithe_upload_data_config(toggle_value: "kithe-upload")
    data = {
      toggle: toggle_value,
      upload_endpoint: Rails.application.routes.url_helpers.admin_direct_app_upload_path
    }

    if Shrine.storages[:cache].kind_of?(Shrine::Storage::S3)
      # uppy will access /admin/s3, where we've mounted shrine's uppy_s3_multipart
      # rack app.
      data[:upload_endpoint] = "/admin"
      data[:s3_storage] = "cache"
      data[:s3_storage_prefix] = Shrine.storages[:cache].prefix
    end

    data
  end
end
