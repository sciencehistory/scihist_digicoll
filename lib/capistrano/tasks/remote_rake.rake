# Invoke a rake task on remote capistrano server.
#
# Copied and customized from https://github.com/sheharyarn/capistrano-rake
#
# Will execute on server identified by cap role(s) `rake_roles` -- locally fixed
# to include the un-merged https://github.com/sheharyarn/capistrano-rake/pull/7
#
namespace :invoke do
  desc "Execute a rake task on a remote server (cap invoke:rake TASK=db:migrate)"
  task :rake do
    if ENV['TASK']

      # Default to :app roles
      rake_roles = fetch(:rake_roles, :app)

      on roles(rake_roles) do
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
