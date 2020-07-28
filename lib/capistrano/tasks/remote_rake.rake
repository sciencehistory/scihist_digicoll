# Invoke a rake task on remote capistrano server.
#
# Copied and customized from https://github.com/sheharyarn/capistrano-rake
#
# Will execute on server identified by cap role(s) `rake_roles` -- locally fixed
# to include the un-merged https://github.com/sheharyarn/capistrano-rake/pull/7
#
# Also added a feature to respect `rake_primary_only` setting to run on only primary server
# with role, that is only ONE server if we have multiple jobs servers, which is pretty much
# what we want for what we use this for.
namespace :invoke do
  desc "Execute a rake task on a remote server (cap invoke:rake TASK=db:migrate)"
  task :rake do
    if ENV['TASK']

      # Default to :app roles
      rake_roles = fetch(:rake_roles, :app)

      rake_servers = if fetch(:rake_primary_only, false).to_s == "true"
        primary(rake_roles)
      else
        roles(rake_roles)
      end

      on rake_servers do
        within current_path do
          with rails_env: fetch(:rails_env) do
            execute :rake, ENV['TASK']
          end
        end
      end

    else
      puts "\n\nFailed! You need to specify the 'TASK' parameter!",
           "Usage: cap <stage> invoke:rake TASK=your:task"
    end
  end

end
