namespace :scihist do
  namespace :data_fixes do
    desc """
      Remove orphaned assets.
      See https://github.com/sciencehistory/scihist_digicoll/issues/2292 .
      bundle exec rake scihist:data_fixes:remove_orphaned_assets
    """
    task :remove_orphaned_assets => :environment do
      Asset.transaction do
        Rails.logger.info "Deleting from 'Water Cure'."
        Asset.where(parent: nil).
          select {|a| a.file.metadata["filename"].start_with?('b10855038') }.
          each { |a| a.destroy }

        Rails.logger.info "Deleting from Beckman"
        Asset.where(parent: nil).
          select {|a| a.file.metadata["filename"].start_with?('2012-002_') }.
          each { |a| a.destroy }
      end
    end
  end
end
