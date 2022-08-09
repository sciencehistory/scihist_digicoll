namespace :scihist do
  namespace :data_fixes do
    desc "move Collection opac URL in related_url to external_id bib"
    task :migrate_collection_bib_ids => [:environment] do
      progress_bar = ProgressBar.create(total: Collection.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      Kithe::Indexable.index_with(batching: true) do
        Collection.find_each do |collection|
          related_urls = collection.related_url.dup
          related_urls.each do |url|
            if url =~ RelatedUrlFilter::OPAC_PREFIX_RE
              collection.external_id += [{ category: "bib", value: url.sub(RelatedUrlFilter::OPAC_PREFIX_RE, '')}]
              collection.related_url.delete(url)
              collection.save!

              progress_bar.log("updated #{collection.friendlier_id}")
            end
            progress_bar.increment
          end
        end
      end
    end
  end
end
