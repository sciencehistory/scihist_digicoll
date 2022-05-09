namespace :scihist do
  namespace :active_encode_status do


    desc """
    Creates jobs to update ActiveEncode status for all non-complete jobs registered

    Also deletes old no longer needed status records.

    You want a scheduled job to run this periodically, maybe once an hour.
    """
    task :update => :environment do
      ActiveEncodeStatus.running.find_each do |job_status|
        RefreshActiveEncodeStatusJob.perform_later(job_status)
      end

      # And delete any old ones that are not running, use delete_all, one
      # quick SQL, no Rails callbacks.
      ActiveEncodeStatus.not_running.where("updated_at < ?", 7.days.ago).delete_all
    end
  end
end
