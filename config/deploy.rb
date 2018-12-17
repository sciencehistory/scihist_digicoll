# Our roles:
# :web - the box is running rails code & serving it over http
# :app - the box is our primary app server
# :jobs - the box is running our background jobs
# :db - the box is running our rails db
# :solr - the box is running our solr index

# config valid only for current version of Capistrano
lock '3.11.0'

set :application, 'scihist_digicoll'
set :repo_url, 'https://github.com/sciencehistory/scihist_digicoll.git'
#set :branch, 'master'
set :deploy_to, '/opt/scihist_digicoll'
set :log_level, :info
set :keep_releases, 5
# label deploys with server local time instead of utm
set :deploytag_utc, false

# use 'passenger-config restart-app' to restart passenger
set :passenger_restart_with_touch, false

# send some data to whenever
#set :whenever_identifier, ->{ "#{fetch(:application)}_#{fetch(:stage)}" }
#set :whenever_roles, [:app, :jobs, :cron]

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
      if ENV['solr_restart'].eql? "true"
        execute :sudo, "/usr/sbin/service solr restart"
      else
        # the querystring doesn't come through without the quotes
        execute :curl, '"localhost:8983/solr/admin/cores?action=reload&core=collection1"'
      end
    end
  end
  after "deploy:log_revision", "chf:restart_or_reload_solr"
end
