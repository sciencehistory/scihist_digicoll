namespace :scihist do
  namespace :report_orphans do
    desc "report any detected 'orphaned' original files, no longer referenced by assets"
    task :originals => :environment do
      OrphanS3Originals.new(show_progress_bar: true).report_orphans
    end
  end
end
