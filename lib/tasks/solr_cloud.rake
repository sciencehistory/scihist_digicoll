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

      updater.upload_and_create_collection(configset_name: updater.configset_digest_name)
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
