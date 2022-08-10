namespace :scihist do
  namespace :data_fixes do
    desc "Remove opac URLs from Work#related_url"
    task :remove_related_url_opac => [:environment] do
      progress_bar = ProgressBar.create(total: Work.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Indexable.index_with(batching: true) do
        Work.find_each do |work|
          related_urls = work.related_url.dup

          related_urls.each do |url|
            if url =~ RelatedUrlFilter::OPAC_PREFIX_RE
              work.related_url.delete(url)
              work.save!

              progress_bar.log("updated #{work.friendlier_id}")
            end
            progress_bar.increment
          end
        end
      end
    end
  end
end
