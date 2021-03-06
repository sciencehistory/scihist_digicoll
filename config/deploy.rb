# Our roles:
# :web - the box running rails code & serving it over http
# :app - the box is our primary app server
# :jobs - the box is running our background jobs
#
# Note we do not have a role for :db, because capistrano does nothing with
# the db server (when it's a separate server), and doesn't even have access to it
# (no `digcol` account on it set up with ssh keys). The host/port of services
# on the db server will be provided to cap-controlled servers by ansible in
# the local_env.yml file.

# config valid only for current version of Capistrano
lock '~> 3.14'

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

# We don't use a `:db` role, cause it makes no sense.
# Run migrations on, oh, say, the first :jobs server.
set :migration_role, :jobs

# cap variables used for AWS EC2 server autodiscover
set :ssh_user, "digcol"
set :server_autodiscover_application, "scihist_digicoll"
# We have things tagged in EC2 using 'staging' or 'production' the same values
# we use for capistrano stage.
set :server_autodiscover_service_level, fetch(:stage)
# Expect all of these to be set, or we will warn.
set :server_autodiscover_expected_roles, [:web, :app, :jobs, :cron]



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
#set :linked_files, fetch(:linked_files, []).push('config/initializers/devise.rb', 'config/blacklight.yml', 'config/database.yml', 'config/redis.yml', 'config/secrets.yml', 'config/solr.yml', 'config/local_env.yml')

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
#
# And if we have multiple jobs servers, we still only
# want to execute on ONE of them, the one marked primary, or else just
# first one listed. (can be overridden with env PRIMARY_ONLY=false)
set :rake_roles, [:jobs]
set :rake_primary_only, ENV["PRIMARY_ONLY"] || true

# This is a no-op task, but our server definition script currently
# outputs to console the server definitions, so a no-op task will do it.
desc "list auto-disocvered EC2 servers"
task :list_ec2_servers


# https://stuff-things.net/2017/03/22/capistrano-ssh/
desc "ssh to a jobs server"
task :jobs_ssh do
  on primary(:jobs) do |host|
    command = "cd #{fetch(:deploy_to)}/current && exec $SHELL -l"
    ssh_command = "ssh -l #{host.user} #{host.hostname} -p #{host.port || 22} -t '#{command}'"
    puts ssh_command # if fetch(:log_level) == :debug
    exec ssh_command
  end
end

namespace :jobs_ssh do
  desc "ssh to a jobs server and open up a rails console"
  task :console do
    on primary(:jobs) do |host|
      command = "hostname && echo && cd #{fetch(:deploy_to)}/current && bundle exec rails console -e #{fetch(:rails_env)}"
      ssh_command = "ssh -l #{host.user} #{host.hostname} -p #{host.port || 22} -t '#{command}'"
      puts ssh_command
      puts
      exec ssh_command
    end
  end
end


namespace :deploy do

  # For cap deploy to notify slack:
  #   * you need `set :slack_notify, true` in the relevant stage file (eg ./config/deploy/staging.rb)
  #   * you need a shell ENV var on the machine you are deploying from, SLACK_NOTIFICATION_WEBHOOK
  #     set to an authorized webhook, which looks like https://hooks.slack.com/services/{opaque stuff}/{opaque stuff}/{opaque stuff}
  task :register_slack_notify do
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
  end
  before "started", :register_slack_notify

  after :restart, :clear_cache do
    on roles(:web), in: :groups, limit: 3, wait: 10 do
      # Here we can do anything such as:
      # within release_path do
      #   execute :rake, 'cache:clear'
      # end
    end
  end
end

namespace :scihist do
  # Restart resque-pool.
  desc "Restart resque-pool"
  task :resquepoolrestart do
    on roles(:jobs) do
      execute :sudo, "/usr/sbin/service resque-pool restart"
    end
  end
  after "deploy:symlink:release", "scihist:resquepoolrestart"

  desc "load local solr config into solr cloud, running on a jobs server"
  task :solr_cloud_sync_configset do
    on primary(:jobs) do
      within current_path do
        with rails_env: fetch(:rails_env) do
          begin
            execute :rake, "scihist:solr_cloud:sync_configset"
          rescue StandardError => e
            colors = SSHKit::Color.new($stderr)
            $stderr.puts colors.colorize("ERROR: Could not sync configset! #{e}, backtrace:", :red)
            $stderr.puts e.backtrace
          end
        end
      end
    end
  end

  after "deploy:log_revision", "scihist:solr_cloud_sync_configset"
end
