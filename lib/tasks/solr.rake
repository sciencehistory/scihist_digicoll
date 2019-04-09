# Rake tasks adapted and customized from those that come with solr_wrapper, but the
# ones in solr_wrapper were old and not very maintained and didn't do quite what we want, including:
# * Using our .solr_wrapper.yml config file(s)
# * Creating the collection specified in .solr_wrapper.yml config if necessary
# * Better status information
#
# Compare at https://github.com/cbeer/solr_wrapper/blob/cd17e4908825d7dca3ca2ba8ab5d92dc02eb38c1/lib/solr_wrapper/tasks/solr_wrapper.rake

require 'pastel'

namespace :solr do
  desc 'Install a clean version of solr. Replaces the existing copy if there is one.'
  task :clean do
    SolrWrapper.instance.tap do |instance|
      puts "Installing clean version of solr at #{File.expand_path(instance.instance_dir)}"
      instance.remove_instance_dir!
      instance.extract_and_configure
    end
  end

  desc 'start solr, installing if necessary'
  task :start do
    SolrWrapper.instance.tap do |instance|
      puts "Starting solr at #{instance.config.url}..."
      instance.start
      instance.create(instance.config.collection_options)
      puts "Started, running at #{instance.instance_dir}, logs at #{instance.instance_dir}/server/logs"
    end
  end

  desc 'restart solr'
  task :restart do
    puts "Restarting solr"
    SolrWrapper.instance.restart
  end

  desc 'stop solr'
  task :stop do
    SolrWrapper.instance.tap do |instance|
      collection_options = instance.config.collection_options
      if collection_options && !collection_options[:persist]  && col_name = collection_options[:name]
        begin
          instance.delete col_name
        rescue StandardError => e
          # we don't care if we couldn't connect, it is hard to rescue though
          unless e.message =~ /Connection refused/
            raise e
          end
        end
      end
      instance.stop
    end
  end

  desc "output of running `solr status`"
  task :status do


    SolrWrapper.instance.tap do |instance|
      puts "solr install at #{instance.instance_dir}\n\n"

      # yes, it's a protected method in solr_wrapper so we need to cheat. :(
      solr_status = SolrWrapper.instance.send(:exec, 'status').read

      # SolrStatus.instance.running? just does this, we want to avoid double
      # expensive `./bin/solr status` runs.
      running = !!(solr_status =~ /running on port #{instance.port}/)

      puts "Configured Solr at #{instance.config.url} appears running? #{Pastel.new.decorate(running.to_s.upcase, running ? :green : :red)}"
      puts solr_status
    end
  rescue Errno::ENOENT => e
    puts "#{e.message}\nSolr appears not be installed at all. Run ./bin/rake solr:clean or ./bin/rake solr:start"
  end

  desc "open solr in browser (MacOS)"
  task :browser do
    `open #{SolrWrapper.instance.config.url}`
  end

end
