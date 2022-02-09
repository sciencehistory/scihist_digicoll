namespace :scihist do
  namespace :data_fixes do

    desc """
      Add Content-Type-Base tag to all S3 originals and derivatives with appropriate value.
      Going forward, should be done automatically on ingest, but this takes care of existing.
      WARNING: Will override ANY existing object-level tags. (We don't have any now, so should
      be fine)
    """
    task :set_s3_object_content_type_tags => :environment do
      scope = Asset

      # useful for testing/debugging, limit to just so many assets
      if ENV["TEST_LIMIT"]
        limit = ENV["TEST_LIMIT"].to_i
      end

      files_processed = 0

      # APPROXIMATE, 9 derivs per asset
      file_count = Asset.count * 10
      progress_bar = ProgressBar.create(total: file_count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_each do |asset|
        ([asset.file] + asset.file_derivatives.values).each do |shrine_file|
          storage = shrine_file.storage

          if storage.kind_of?(Shrine::Storage::S3)
            content_type = shrine_file.metadata&.dig("mime_type").presence || "unknown"
            content_type_base = content_type.split("/").first

            # https://docs.aws.amazon.com/sdk-for-ruby/v3/api/Aws/S3/Client.html#put_object_tagging-instance_method
            storage.client.put_object_tagging({
              bucket: storage.bucket.name,
              key: storage.object_key(shrine_file.id),
              tagging: {
                tag_set: [
                  {
                    key: "Content-Type-Base",
                    value: content_type_base,
                  }
                ]
              }
            })
          end
          files_processed += 1
          progress_bar.increment if files_processed < file_count
        end
        break if limit && files_processed >= limit
      end
      puts "Tagged #{files_processed} files"
    end
  end
end
