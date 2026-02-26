namespace :scihist do
  task :validate_oral_history_chunks => [:environment] do

    total = OralHistoryContent.count
    progress_bar = ProgressBar.create(total: total, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

    errors = []

    # for now fetch all members, because we need to see if we have a PDF transcript published
    # to validate, as a result of https://github.com/sciencehistory/scihist_digicoll/issues/3253.
    # There are various wyas we could optimize this.
    OralHistoryContent.includes(:oral_history_chunks, work: :members).strict_loading.find_each(batch_size: 10) do |oral_history_content|
      begin
        OralHistory::ChunkValidator.new(oral_history_content).validate!
      rescue OralHistory::ChunkValidator::Error => e
        errors << e
      ensure
        progress_bar.increment
      end
    end

    if errors.present?
      error_display = "Oral Histor Chunks: #{errors.count} errors out of #{total} Oral Histories.\n\n"
      error_display += errors.collect { |e| "#{e.message}\n   #{ScihistDigicoll::Env.lookup(:app_url_base)}/admin/works/#{e.friendlier_id}#tab=nav-oral-histories\n"}.join("\n")

      # log
      Rails.logger.info("scihist:validate_oral_history_chunks: Errors found\n\n#{error_display}")

      # and notify error handling services (HoneyBadger) and/or print to console



      #puts error_display
    else
      Rails.logger.info("scihist:validate_oral_history_chunks: All validated")
    end
  end
end
