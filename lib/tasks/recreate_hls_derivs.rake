namespace :scihist do
  desc """
    Goes through all video assets. Where needed, adds a perform_later
    job to :special_jobs to recreate HLS derivatives for them.

    This does NOT actually do the processing.

    bundle exec rake scihist:recreate_hls_derivs
  """
  task :recreate_hls_derivs => :environment do
    jobs_enqueued = 0
    video_work_scope =  Work.where("json_attributes -> 'format' ?  'moving_image'")
    progress_bar = ProgressBar.create(total: video_work_scope.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    queue = :special_jobs
    video_work_scope.find_each(batch_size: 10) do |w|
      progress_bar.increment
      video_assets = w.members.select { |m| m&.content_type&.start_with?("video/") }
      unless video_assets.present?
        progress_bar.log "INFO: SKIP #{w.title}. No video assets."
        next
      end
      video_assets.each do |v|
        CreateHlsVideoJob.set(queue: queue).perform_later(v)
        jobs_enqueued = jobs_enqueued + 1
      end
    end
    progress_bar.log "Added #{jobs_enqueued} assets into the queue to have their derivatives re-encoded."
  end
end