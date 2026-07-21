namespace :scihist do
  desc """
    Validate all OralHistoryChunk for some basic formal consistency.

    Will normally print out report to console, but if you set env BG_MODE=true
    then it will instead log and report to error reporting service.

    bundle exec rake scihist:validate_oral_history_chunks
    BG_MODE=true bundle exec rake scihist:validate_oral_history_chunks
  """

  task :validate_oral_history_chunks => [:environment] do
    bg_mode = ENV['BG_MODE'] == "true"


    total = OralHistoryContent.count
    unless bg_mode
      progress_bar = ProgressBar.create(total: total, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
    end

    errors = []

    OralHistoryContent.includes(:oral_history_chunks, :work).strict_loading.find_each(batch_size: 2) do |oral_history_content|
      begin
        OralHistory::ChunkValidator.new(oral_history_content).validate!
      rescue OralHistory::ChunkValidator::Failure => e
        errors << e
      ensure
        progress_bar&.increment
      end

      # Try to keep from using too much heroku memory, at cost of more GC than we need
      GC.start
    end

    if errors.present?
      error_display = "Oral Histor Chunks: #{errors.count} errors out of #{total} Oral Histories.\n\n"
      error_display += errors.collect { |e| "#{e.friendlier_id}: #{e.message}\n   #{ScihistDigicoll::Env.lookup(:app_url_base)}/admin/works/#{e.friendlier_id}#tab=nav-oral-histories\n"}.join("\n")

      if bg_mode
        # log, which when running on heroku will also show up in console
        Rails.logger.info("scihist:validate_oral_history_chunks: Errors found\n\n#{error_display}")

        # and notify error handling services (HoneyBadger) and/or print to console
        # group by id in hash, and extract messages
        grouped_errors = errors.group_by(&:friendlier_id).collect do |id, exceptions|
          [id, exceptions.collect { |e| "#{e.message} ; #{ScihistDigicoll::Env.lookup(:app_url_base)}/admin/works/#{e.friendlier_id}#tab=nav-oral-histories"}]
        end.to_h

        Rails.error.report(
          OralHistory::ChunkValidator::Failure.new("scihist:validate_oral_history_chunks errors found"),
          context: {
            "validate_oral_history_chunks": grouped_errors
          }
        )
      else
        $stderr.puts error_display
      end
    else
      if bg_mode
        Rails.logger.info("scihist:validate_oral_history_chunks: All validated")
      else
        $stderr.puts "scihist:validate_oral_history_chunks: All validated"
      end
    end
  end
end
