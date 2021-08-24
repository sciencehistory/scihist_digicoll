
#
# monkey patch resque adapter to be willing to enqueue_at NOW,
# to let us use ActiveJob retry_on with wait: 0. Resque
# can't enqueue in the future without resque-scheduler,
# but we can enqueue at wait:0/NOW.
#
module AllowResqueEnqueueAtNow
  def enqueue_at(job, timestamp) #:nodoc:de
    if !Resque.respond_to?(:enqueue_at_with_queue) && timestamp.to_i <= Time.now.to_i
      # we don't have resque-scheduler, but it's asking for it to run now anyway,
      # just enqueue as usual.
      enqueue(job)
    else
      super
    end
  end
end

ActiveJob::QueueAdapters::ResqueAdapter.prepend(AllowResqueEnqueueAtNow)
