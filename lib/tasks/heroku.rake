namespace :scihist do
  namespace :heroku do

    desc "our custom code for running in heroku release phase"
    task :on_release do
      if ENV['DATABASE_URL']
        Rake::Task["db:migrate"].invoke
      else
        $stderr.puts "\n!!! WARNING, no ENV['DATABASE_URL'], not running rake db:migrate as part of heroku release !!!\n\n"
      end

      if ENV['SOLR_URL']
        Rake::Task["scihist:solr_cloud:sync_configset"].invoke
      else
        $stderr.puts "\n!!! WARNING, no ENV['SOLR_URL'], not running rake scihist:solr_cloud:sync_configset as part of heroku release !!!\n\n"
      end
    end

    desc "Copy remote work from staging to local dev, with all data"
    task :copy_data, [:work_friendlier_id, :force_erase] => :environment do |t, args|
      heroku_app = ENV['HEROKU_APP'] || "scihist-digicoll-staging"

      unless args[:work_friendlier_id]
        raise ArgumentError, "missing :work_friendlier_id arg"
      end

      if args[:force_erase] == "true"
        Work.find_by_friendlier_id(args[:work_friendlier_id])&.destroy
      end

      Tempfile.open do |tempfile|
        $stderr.puts "Retrieving..."

        # We want to capture the outputof our rake task, that will be serialized JSON.
        # But heroku insists on putting log lines in stdout too,
        # our custom RAILS_DISABLE_LOGGING=true works around at cost of logs -- plus disable stderr in case
        # it's going to get in the way!
        stdout, _stderr, status = Open3.capture3("heroku run RAILS_DISABLE_LOGGING=true rake scihist:copy_staging_work:serialize_work[#{args[:work_friendlier_id]}] --exit-code -a #{heroku_app} 2>/dev/null")

        if status != 0
          raise "Remote heroku export failed? #{stdout}"
        end

        # it's hard to get rails and our gems (*cough* scout) to avoid polluting stdout,
        # that we really mean just to be json we're going to parse. Let's try scanning
        # to first `{` at the beginning of a line, which is hopefully our actual JSON.
        tempfile.write(stdout.slice(stdout.index(/^\{/), stdout.length))
        tempfile.flush

        $stderr.puts "Loading..."
        Rake::Task["scihist:copy_staging_work:restore_work"].invoke(tempfile.path)
      end
    end
  end
end
