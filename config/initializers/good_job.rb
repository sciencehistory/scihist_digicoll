Rails.application.configure do
  # Preserve completed records, so we can view them in dashboard
  #
  # Nope this does not seem to work...
  #Rails.application.config.good_job.preserve_job_records = true
  config.good_job.preserve_job_records = true

  # Do NOT retry errors that make it to good_job.
  #
  # This kind of ALWAYS needs to be false to avoid infinite loop on erroring job,
  # why doesn't it default to false??
  #
  # https://github.com/bensheldon/good_job#retries
  config.good_job.retry_on_unhandled_error = false

  # And when we do manually clear old job completion records, we do NOT
  # want to clear any currently listed as "discarded" (ie failed)
  config.good_job.cleanup_discarded_jobs = false
end
