namespace :scihist do
  namespace :active_encode_status do


    desc """
    Updates ActiveEncode status for all non-complete jobs registered. Serially,
    so can take a while if there are many in progress ActiveEncode jobs.

    Also deletes old no longer needed status records.

    You want a scheduled job to run this periodically, maybe once an hour.
    """
    task :update => :environment do
      ScihistDigicoll::Util.find_each(ActiveEncodeStatus.running) do |job_status|
        # We intentionally do these serially to avoid MediaConvert rate limits
        job_status.refresh_from_aws
      end

      # And delete any old ones that are not running, use delete_all, one
      # quick SQL, no Rails callbacks.
      ActiveEncodeStatus.not_running.where("updated_at < ?", 7.days.ago).delete_all
    end
  end
end
