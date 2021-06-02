namespace :scihist do
  namespace :orphans do
    namespace :report do
      desc "report any detected 'orphaned' original files, no longer referenced by assets"
      task :originals => :environment do
        OrphanS3Originals.new(show_progress_bar: ENV['PROGRESS_BAR'] != "false").report_orphans
      end

      desc "report any orphaned public derivatives which do not correspond to an existing asset pk"
      task :derivatives => :environment do
        OrphanS3Derivatives.new(show_progress_bar: ENV['PROGRESS_BAR'] != "false").report_orphans
      end

      desc "report any orphaned restricted derivatives which do not correspond to an existing asset pk"
      task :restricted_derivatives => :environment do
        OrphanS3RestrictedDerivatives.new(show_progress_bar: ENV['PROGRESS_BAR'] != "false").report_orphans
      end

      desc "report any orphaned S3 tilesets which do not correspond to an existing asset pk/md5"
      task :dzi => :environment do
        OrphanS3Dzi.new(show_progress_bar: ENV['PROGRESS_BAR'] != "false").report_orphans
      end
    end

    namespace :delete do
      desc "delete orphaned originals"
      task :originals => :environment do
        OrphanS3Originals.new(show_progress_bar: ENV['PROGRESS_BAR'] != "false").delete_orphans
      end

      desc "delete orphaned public derivatives"
      task :derivatives => :environment do
        OrphanS3RestrictedDerivatives.new(show_progress_bar: ENV['PROGRESS_BAR'] != "false").delete_orphans
      end

      desc "delete orphaned restricted derivatives"
      task :restricted_derivatives => :environment do
        OrphanS3Derivatives.new(show_progress_bar: ENV['PROGRESS_BAR'] != "false").delete_orphans
      end

      desc "delete orphaned DZI"
      task :dzi => :environment do
        OrphanS3Dzi.new(show_progress_bar: ENV['PROGRESS_BAR'] != "false").delete_orphans
      end
    end
  end
end
