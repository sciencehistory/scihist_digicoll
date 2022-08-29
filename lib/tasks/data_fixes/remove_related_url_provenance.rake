namespace :scihist do
  namespace :data_fixes do

    desc """
      Remove provenance note from Work#{}related_urls
    """
    task :remove_related_url_provenance_note => :environment do
      PROVENANCE_NOTE_URL = "https://www.sciencehistory.org/fine-art#provenance"

      progress_bar = ProgressBar.create(total: Work.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Indexable.index_with(batching: true) do
        Work.find_each do |work|
          if work.related_url.include?(PROVENANCE_NOTE_URL)
            work.related_url.delete(PROVENANCE_NOTE_URL)
            work.save!
            progress_bar.log("removed provenance related_url: #{work.friendlier_id}")
          end
          progress_bar.increment
        end
      end
    end
  end
end

