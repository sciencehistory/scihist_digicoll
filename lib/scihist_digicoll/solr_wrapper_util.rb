module ScihistDigicoll
  module SolrWrapperUtil
    # Pass in a solr_wrapper instance, we'll start it, AND create a collection
    # if specified in solr_wrapper config.
    def self.start_with_collection(instance)
      instance.start
      instance.create(instance.config.collection_options)
    end

    # Pass in a solr_wrapper instance, we'll stop it, AND delete the collection
    # specified in solr_wrapper config if persist: false
    def self.stop_with_collection(instance)
      collection_options = instance.config.collection_options
      if collection_options && !collection_options[:persist]  && col_name = collection_options[:name]
        begin
          instance.delete col_name
        rescue StandardError => e
          # we don't care if we couldn't connect, maybe it wasn't already started.
          # It is hard to rescue though, and solrwrapper is already doing way too many
          # extra solr http calls.
          unless e.message =~ /Connection refused/ || e.message =~ /unload non-existent core/
            raise e
          end
        end
      end
      instance.stop
    end
  end
end
