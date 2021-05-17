namespace :scihist do
  namespace :data_fixes do
    legacy_oh_url_re = /https?:\/\/oh\.sciencehistory\.org\//

    desc "list all :related_url to oh.sciencehistory.org"
    task :list_microsite_urls => :environment do
      Work.find_each do |work|
        if work.related_url.present? && work.related_url.grep(legacy_oh_url_re).present?
          puts work.related_url.grep(legacy_oh_url_re).collect { |u| "#{work.friendlier_id}: #{u}"}
        end
      end
    end

    desc "remove all :related_url to oh.sciencehistory.org"
    task :delete_microsite_urls => :environment do
      progress_bar = progress_bar = ProgressBar.create(total: Work.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      Work.transaction do
        Kithe::Indexable.index_with(batching: true) do
          Work.find_each do |work|
            if work.related_url.present? && work.related_url.grep(legacy_oh_url_re).present?
              work.related_url = work.related_url.select {|u| u !~ legacy_oh_url_re}
              work.save!
            end
            progress_bar.increment
          end
        end
      end
    end
  end
end
