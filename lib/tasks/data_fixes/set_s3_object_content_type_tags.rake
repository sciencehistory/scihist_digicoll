namespace :scihist do
  namespace :data_fixes do

    desc """
      Add Content-Type-Base tag to all S3 originals and derivatives with appropriate value.
      Going forward, should be done automatically on ingest, but this takes care of existing.
      WARNING: Will override ANY existing object-level tags. (We don't have any now, so should
      be fine)
    """

    # For batch processing that might take a while:
    #

    task :set_s3_object_content_type_tags => :environment do
      # useful for testing/debugging, limit to just so many assets
      if ENV["TEST_LIMIT"]
        limit = ENV["TEST_LIMIT"].to_i
      end

      log_period = ENV['LOG_PERIOD_S'].present? ? ENV['LOG_PERIOD_S'].to_i : 10.minutes

      use_progress_bar = ENV["PROGRESS_BAR"] == "true"

      files_processed = 0

      if use_progress_bar
        # APPROXIMATE, 9 derivs per asset
        file_count = Asset.count * 10
        progress_bar = ProgressBar.create(total: file_count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      end

      thread_pool = Concurrent::ThreadPoolExecutor.new(
         min_threads: 10,
         max_threads: 10,
         max_queue: 200,
         fallback_policy: :caller_runs
      )

      last_record_processed = nil
      last_progress_log = Time.now

      Rails.logger.info "set_s3_object_content_type_tags: starting #{ENV['START_AT_PK']}"

      if ENV['START_AT_PK']
        finder = Asset.find_each(start: ENV['START_AT_PK'])
      else
        finder = Asset.find_each
      end

      finder.each do |asset|
        ([asset.file] + asset.file_derivatives.values).each do |shrine_file|
          thread_pool.post do
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
          end
          files_processed += 1
          progress_bar.increment if use_progress_bar && files_processed < file_count
        end
        break if limit && files_processed >= limit

        last_record_processed = asset
        if files_processed % 10 == 0 && ((Time.now - last_progress_log) > log_period)
          Rails.logger.info("set_s3_object_content_type_tags: processed #{files_processed} assets, up to Asset PK #{last_record_processed.id}")
          last_progress_log = Time.now
        end
      end

      thread_pool.shutdown
      thread_pool.wait_for_termination
      Rails.logger.info "set_s3_object_content_type_tags: thread pool terminated: #{thread_pool.shutdown?}"

      progress_bar.finish if use_progress_bar
      puts "set_s3_object_content_type_tags: Tagged #{files_processed} files"
      Rails.logger.info "set_s3_object_content_type_tags: Tagged #{files_processed} files"
    end
  end
end
