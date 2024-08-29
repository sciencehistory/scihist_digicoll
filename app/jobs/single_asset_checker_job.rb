class SingleAssetCheckerJob < ApplicationJob
  def perform(asset)
    checker = FixityChecker.new(asset)
    checker.check
    checker.prune_checks
  end

  # We think this almost always means Asset was deleted sometime after this
  # job was queued but before this job executed, so the Asset no longer exists
  #
  # This will probably prevent the job from retring on error even once, as it
  # usually does -- that should be fine.
  discard_on ActiveJob::DeserializationError do |job, error|
    # This is probably already logged by Rails with these same details,
    # but just to be sure we have it logged, let's do it too.
    Rails.logger.error("#{job.class.name} (#{job&.id}): Cancelling job due to ActiveJob::DeserializationError: #{error&.message}")
  end
end
