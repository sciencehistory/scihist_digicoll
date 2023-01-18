# Heroku-recommende configuration from
# https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#config
#
# By default without setting heroku config this will create **1** puma processes, with 5 threads. (1
# worker is all that fits for our app in a small heroku dyno?)
# Setting heroku config vars can tune these.

workers Integer(ENV['WEB_CONCURRENCY'] || 1)
threads_count = Integer(ENV['RAILS_MAX_THREADS'] || 5)
threads threads_count, threads_count

# https://github.com/puma/puma/blob/master/5.0-Upgrade.md
fork_worker

preload_app!

rackup      DefaultRackup
port        ENV['PORT']     || 3000
environment ENV['RACK_ENV'] || 'development'

on_worker_boot do
  # Worker specific setup for Rails 4.1+
  # See: https://devcenter.heroku.com/articles/deploying-rails-applications-with-the-puma-web-server#on-worker-boot
  ActiveRecord::Base.establish_connection
end
