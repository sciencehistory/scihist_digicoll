class ApplicationJob < ActiveJob::Base
  # All our jobs should be idempotent, let's automatically retry them all for any
  # error.
  #
  # This can for instance automatically take care of long-running jobs interupted by a host restart.
  #
  # Resque, which we ae are using at the moment, by default doesn't support
  # future-scheduled jobs, so we retry just once, immediately. Could have
  # a more sophisticated retry pattern with a back-end that supports future-scheduling.
  if ScihistDigicoll::Env.lookup(:activejob_auto_retry)
    retry_on StandardError, attempts: 2, wait: 0
  end
end
