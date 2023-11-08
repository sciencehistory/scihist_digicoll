require 'active_job/log_subscriber'

# ActiveJob default logging around retry events is missing a lot of info that IS
# included in other events, including "tags" (Rails tagged logging) for ActiveJob and job-id.
#
# We want to customize it to make retry/discard log events more similar to other ActiveJob log events,
# so we can more easily see and monitor what's going on.
#
# The ActiveSupport::Subscriber archirtecture doesn't make this super easy.
# After delving into Rails code, we make our own subclass of ActiveJob::LogSubscriber, override
# the methods with log lines we want to change.
#
# Then we subscribe our custom one, and UNSUBSCRIBE the original one.
#
# Some background that didn't end up too useful:
# * how lograge unsubscribes things:
#   https://github.com/roidrage/lograge/blob/1729eab7956bb95c5992e4adab251e4f93ff9280/lib/lograge.rb#L119
# * An example of adding a notification/log line a different way:
#
class LocalActiveJobLogSubscriber < ActiveJob::LogSubscriber
  def enqueue_retry(event)
    job = event.payload[:job]
    ex = event.payload[:error]
    wait = event.payload[:wait]

    Rails.logger.tagged(*_needed_additional_tags(job.job_id)) do
      # default logs this one at 'info', let's change to 'warn'
      warn do
        if ex
          "Retrying #{job.class} (Job ID: #{job.job_id}) after #{job.executions} attempts in #{wait.to_i} seconds, due to a #{ex.class} (#{ex.message})."
        else
          "Retrying #{job.class} (Job ID: #{job.job_id}) after #{job.executions} attempts in #{wait.to_i} seconds."
        end
      end
    end
  end

  def retry_stopped(event)
    job = event.payload[:job]
    ex = event.payload[:error]


    Rails.logger.tagged(*_needed_additional_tags(job.job_id)) do
      error do
        "Stopped retrying #{job.class} (Job ID: #{job.job_id}) after #{job.executions} attempts, due to a #{ex.class} (#{ex.message})."
      end
    end
  end

  def discard(event)
    job = event.payload[:job]
    ex = event.payload[:error]

    Rails.logger.tagged(*_needed_additional_tags(job.job_id)) do
      error do
        "Discarded #{job.class} (Job ID: #{job.job_id}) due to a #{ex.class} (#{ex.message})."
      end
    end
  end

  private

  def _needed_additional_tags(job_id)
    tags = []

    unless logger.formatter.current_tags.include?("ActiveJob")
      tags << "ActiveJob"
    end

    unless logger.formatter.current_tags.include?(job_id)
      tags << job_id
    end

    tags
  end

end

# Unsubscribe default ActiveJob logging
ActiveJob::LogSubscriber.detach_from :active_job

# Subsribe ours with custom overrides.
#
# for some reason API makes us specify inherit_all: true to make sure we
# get existing event-handling events we weren't overriding!
LocalActiveJobLogSubscriber.attach_to :active_job, inherit_all: true
