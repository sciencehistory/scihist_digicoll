# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/capistrano.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks

# Due to a bug in honeybadger, the at_exit callback isn't being installed, cause
# honeybadger thinks we're sinatra, so error reports can be lost at app shutdown --
# and in the special case of rake task, usually will be.
# We do this manually. If honeybadger fixes it's thing, this might result
# in double callback, which theoretically isn't great.
# https://github.com/honeybadger-io/honeybadger-ruby/issues/258
if defined?(Honeybadger)
  Honeybadger.install_at_exit_callback
end
