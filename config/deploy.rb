# Our roles:
# :web - the box is running rails code & serving it over http
# :app - the box is our primary app server
# :jobs - the box is running our background jobs
# :db - the box is running our rails db
# :solr - the box is running our solr index

# config valid only for current version of Capistrano
lock '3.11.0'

# Make our EC2 server autodiscover available
include CapServerAutodiscover

set :application, 'scihist_digicoll'
set :repo_url, 'https://github.com/sciencehistory/scihist_digicoll.git'
#set :branch, 'master'
set :deploy_to, '/opt/scihist_digicoll'
set :log_level, :info
set :keep_releases, 5
# label deploys with server local time instead of utm
set :deploytag_utc, false


# cap variables used for AWS EC2 server autodiscover
set :ssh_user, "digcol"
set :server_autodiscover_application, "scihist_digicoll"
# We have things tagged in EC2 using 'staging' or 'production' the same values
# we use for capistrano stage.
set :server_autodiscover_service_level, fetch(:stage)
# Expect all of these to be set, or we will warn.
set :server_autodiscover_expected_roles, [:web, :app, :db, :jobs, :solr, :cron]



# use 'passenger-config restart-app' to restart passenger
set :passenger_restart_with_touch, false
set :passenger_restart_command, 'sudo systemctl restart passenger'
set :passenger_restart_options, ""


# not all machines should run bundler; some won't have ruby
set :bundle_roles, [:web, :jobs, :cron]

# Prompt which branch to deploy; default to current.
ask :branch, `git rev-parse --abbrev-ref HEAD`.chomp

# Default value for :pty is false
# set :pty, true

# Default value for :linked_files is []
#set :linked_files, fetch(:linked_files, []).push('config/initializers/devise.rb', 'config/blacklight.yml', 'config/database.yml', 'config/fedora.yml', 'config/redis.yml', 'config/secrets.yml', 'config/solr.yml', 'config/local_env.yml')

set :linked_files, fetch(:linked_files, []).push('config/local_env.yml')

# Default value for linked_dirs is []
set :linked_dirs, fetch(:linked_dirs, []).push('log', 'tmp/pids', 'tmp/cache', 'tmp/sockets', 'public/system')
# Default value for default_env is {}
# set :default_env, { path: "/opt/ruby/bin:$PATH" }

set :honeybadger_env, fetch(:stage)


# Whenever, only deploy cronjobs on server(s) marked with Capistrano :cron role.
# Right now our cronjobs are general maintenance tasks that _could_ run on any
# server with the Rails app available. We set the "jobs" server to have "cron"
# role.
set :whenever_roles, [:cron]

# When running rake tasks with `cap staging invoke:rake rake:task:name`, via
# the capistrano-rake gem, run them on the jobs host, that's a good one for
# putting extra work on.
set :rake_roles, [:jobs]

if fetch(:slack_notify)
  require_relative '../lib/scihist_digicoll/slackistrano_messaging'
  slack_notification_webhook = ENV["SLACK_NOTIFICATION_WEBHOOK"]
  if slack_notification_webhook
    set :slackistrano, {
      klass: ScihistDigicoll::SlackistranoMessaging,
      webhook: slack_notification_webhook
    }
  else
    set :slackistrano, false
    $stderr.puts "WARN: No ENV['SLACK_NOTIFICATION_WEBHOOK'], can't do slack notification"
  end
else
  set :slackistrano, false
end

# This is a no-op task, but our server definition script currently
# outputs to console the server definitions, so a no-op task will do it.
task :list_ec2_servers

namespace :deploy do

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end

  after "deploy:assets:precompile", "chf:link_custom_error_pages"
end

namespace :chf do

  desc "link our static html error pages in public/"
  task "link_custom_error_pages" do
    on roles(:web) do
      within release_path do
        ["404.html", "500.html"].each do |filename|
          execute "./config/deploy/bin/link_custom_error_pages.rb", filename
        end
      end
    end
  end

  # Restart resque-pool.
  desc "Restart resque-pool"
  task :resquepoolrestart do
    on roles(:jobs) do
      execute :sudo, "/usr/sbin/service resque-pool restart"
    end
  end
  after "deploy:symlink:release", "chf:resquepoolrestart"

  desc "add solr_restart=true to your cap invocation (e.g. on first solr deploy), otherwise it will reload config files"
  task :restart_or_reload_solr do
    on roles(:solr) do
      if ENV['solr_restart'] == "true"
        execute :sudo, "/usr/sbin/service solr restart"
      else
        # Note this is NOT using our solr variable in local_env.yml, it's just hard-coded
        # where to restart, sorry.

        # the querystring doesn't come through without the quotes
        execute :curl, "-s", '"localhost:8983/solr/admin/cores?action=reload&core=collection1"', "--write-out", '"\nhttp response status: %{http_code}\n"'
      end
    end
  end
  after "deploy:log_revision", "chf:restart_or_reload_solr"
end
