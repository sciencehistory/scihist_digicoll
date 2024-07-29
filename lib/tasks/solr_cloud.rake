namespace :scihist do
  # some tasks for managing config sets and collections through solr cloud, such as
  # but not limited to SearchStax-hosted solr.
  #
  # Config for solr location and collection name is taken from ScihistDigicoll:Env solr_url
  #
  # We use config set names that have a fingerprint digest on the end, so they are unique
  # for config content.
  namespace :solr_cloud do

    desc "Create collection using on-disk configuration files, bootstrap on empty solr"
    task :create_collection => :environment do
      updater = SolrConfigsetUpdater.configured

      configset_name = updater.configset_digest_name

      # if configset name already exists, assume it's the one we want, since we put
      # a digest value in configset name, it ought to be! If it's not, we need to upload it
      unless updater.list.include?(configset_name)
        updater.upload(configset_name: configset_name)
      end

      updater.create_collection(configset_name: configset_name)
    end

    desc "upload configset and (re-)attach to collection, only if it is not already up to date"
    task :sync_configset => :environment do
      updater = SolrConfigsetUpdater.configured

      updated = updater.replace_configset_digest

      if updated
        puts "sync_configset: updated config set to #{updated}"
      else
        puts "sync_configset: no update to config set needed"
      end
    end
  end
end
