namespace :scihist do
  namespace :orphans do
    namespace :report do
      desc "report any detected 'orphaned' original files, no longer referenced by assets"
      task :originals => :environment do
        OrphanS3Originals.new(show_progress_bar: true).report_orphans
      end

      desc "report any orphaned derivatives which do not correspond to an existing asset pk"
      task :derivatives => :environment do
        OrphanS3Derivatives.new(show_progress_bar: true).report_orphans
      end
    end

    namespace :delete do
      desc "delete orphaned originals"
      task :originals => :environment do
        OrphanS3Originals.new(show_progress_bar: true).delete_orphans
      end

      desc "delete orphaned derivatives"
      task :derivatives => :environment do
        OrphanS3Derivatives.new(show_progress_bar: true).delete_orphans
      end
    end
  end
end
