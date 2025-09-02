# The hirefire_resource gem has our app providing some info to hirefire.io for
# heroku autoscaling.
#
# Let's only configure it to do anything if we're actually on heroku with HIREFIRE_TOKEN
# configured. This config  won't be operative in dev or CI, OR if/when we're still
# deploying to non-heroku infrastructure, hopefully minimizing any performance
# impact on non-heroku.

if ENV['HIREFIRE_TOKEN']
  HireFire::Resource.configure do |config|

    # https://help.hirefire.io/article/53-job-queue-ruby-on-rails
    # https://github.com/hirefire/hirefire-resource
    config.dyno(:worker) do
      # All queues that aren't in other special purpose queues -- not included are our special worker
      # queues and our on_demand_derivatives_worker queues, possibly others.
      #
      #
      # Pitfall: If we add more queues, we're going to forget to edit here, sorry.
      HireFire::Macro::Resque.queue("default", "mailers")
    end

    config.dyno(:on_demand_derivatives_worker) do
      HireFire::Macro::Resque.queue("on_demand_derivatives")
    end

    # for queue time-based web dyno scaling, if we choose to use that.
    # https://help.hirefire.io/article/49-logplex-queue-time
    # config.log_queue_metrics = true
  end
end
