# Add your own tasks in files placed in lib/tasks ending in .rake,
# for example lib/tasks/heroku.rake, and they will automatically be available to Rake.

require_relative 'config/application'

Rails.application.load_tasks


# Vite tries to install yarn/npm dependencies with `npx ci`, but heroku
# ruby buildpack doesn't have `npx` available, so it will fail.
#
# So we wire up assets:precompile to run `yarn install`, like it did pre-Rails 7,
# as `yarn` is available on heroku ruby buidpack.  At worst, this might mean
# yarn install gets run twice, which should be pretty cheap.
#
# See: https://github.com/ElMassimo/vite_ruby/discussions/316
#
if Rake::Task.task_defined?("assets:precompile") && File.exist?(Rails.root.join("yarn.lock"))
  Rake::Task["assets:precompile"].enhance [ "yarn:install" ]
end
