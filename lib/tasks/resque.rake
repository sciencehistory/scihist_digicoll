# Load the Rails app all the time.
# See https://github.com/resque/resque/wiki/FAQ for more details
require 'resque/tasks'
require 'resque/pool'
require 'resque/pool/tasks'

# This provides access to the Rails env within all Resque workers
task "resque:setup" => :environment

# https://github.com/resque/resque-pool#rake-task-config
# https://github.com/resque/resque-pool/issues/221
task 'resque:pool:setup' do
  ActiveRecord::Base.connection.disconnect!

  Resque::Pool.after_prefork do |j|
    ActiveRecord::Base.establish_connection
  end
end


namespace :scihist do
  namespace :resque do
    desc "prune workers resque knows haven't sent a heartbeat in a while"
    # resque is supposed to do this itself sometimes, but doesn't always.
    task :prune_expired_workers => :environment do
      expired = Resque::Worker.all_workers_with_expired_heartbeats
      if expired.present?
        $stderr.puts "pruning: #{expired}"
        expired.each { |w| w.unregister_worker }
      else
        $stderr.puts "None found"
      end
    end
  end
end
