FactoryBot.define do

  # a Shrine::UploadedFile object with faked metadata. The `file` given
  # IS actually uploaded to `Shrine.storage[:store]`
  #
  # This is used in our Asset factory for faking assets with promoted/stored
  # attached files, quickly.
  #
  # The content-type and other metadata may not match the actual file, that's up
  # to you to specify/provide.
  factory :stored_uploaded_file, class: ::AssetUploader::UploadedFile do
    transient do
      file { File.open((Rails.root + "spec/test_support/images/30x30.png")) }
      content_type { "image/png" }
      width { 30 }
      height { 30 }
      bitrate     { nil }
      audio_bitrate     { nil }
      video_bitrate     { nil }
      audio_sample_rate { nil }
      duration_seconds  { nil }
      md5 { Digest::MD5.hexdigest rand(10000000).to_s }
      sha512 { Digest::SHA512.hexdigest rand(10000000).to_s }
      filename { nil }
      size { nil }
      other_metadata { {} }
      page_count { nil }
    end

    id { SecureRandom.hex }
    storage { "store" }
    metadata do
      {
        "filename"=> filename || File.basename( file ),
        "size"=> size || file.size,
        "mime_type"=> content_type,
        "width"=> width,
        "height"=> height,
        "md5" => md5,
        "duration_seconds" => duration_seconds,
        "bitrate"       => bitrate,
        "audio_bitrate" => audio_bitrate,
        "video_bitrate" => video_bitrate,
        "audio_sample_rate" => audio_sample_rate,
        "sha512" => sha512,
        "page_count" => page_count
      }.merge(other_metadata).compact
    end

    initialize_with { new(
      "id" => id,
      "storage" => storage,
      "metadata" => metadata
    )}

    # no built-in persistence of Shrine::Uploadedfile
    to_create { }

    after(:build) do |uploaded_file, evaluator|
      # actually upload the file to shrine storage
      Shrine.storages[:store].upload(evaluator.file, uploaded_file.id)
    end
  end
end
