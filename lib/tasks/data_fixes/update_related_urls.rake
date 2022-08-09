require "#{Rails.root}/lib/scihist_digicoll/task_helpers/related_url_updater"
namespace :scihist do
  namespace :data_fixes do
    desc "Changes related urls to the new ArchivesSpace URLs."
    # bundle exec rake scihist:data_fixes:update_related_urls
    task :update_related_urls => :environment do
      progress_bar = ProgressBar.create(total: Work.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")      
      updater = ScihistDigicoll::TaskHelpers::RelatedUrlUpdater.new
      Work.transaction do
        Kithe::Indexable.index_with(batching: true) do
          Work.find_each(batch_size: 10) do |work|
            updater.process_work(work)
            progress_bar.increment
          end
        end
      end
      puts "Changes:"
      pp updater.changes
      puts "Errors:"
      pp updater.errors
    end
  end
end