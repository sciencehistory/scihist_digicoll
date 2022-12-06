# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/heroku.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks


# Rails7 stopped automatically doing a `yarn install`, although the yarn:install rake
# task is still available. vite-rails should wire this up  but doesn't yet, so we do.
#
# See https://github.com/ElMassimo/vite_ruby/discussions/316
#
# May be fixed in a future vite-rails, in which case we may want to remove
# this
if Rake::Task.task_defined?("assets:precompile") && File.exist?(Rails.root.join("bin", "yarn"))
  Rake::Task["assets:precompile"].enhance [ "yarn:install" ]
end
