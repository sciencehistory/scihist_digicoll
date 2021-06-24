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
  end
end
