namespace :scihist do
  namespace :data_fixes do
    desc """
      Remove download_small derivative from all assets, remove from S3
    """
    task :remove_download_small_derivatives => :environment do
      progress_bar = ProgressBar.create(total: Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      # https://shrinerb.com/docs/changing-derivatives#removing-derivatives
      #
      # Has a recipe for concurrency-safe derivative changes... but it also slows down
      # things a LOT as it involves a reload. We will do it less safely, it's fine for
      # our needs.
      Asset.find_in_batches(batch_size: 200) do |batch|
        batch.each do |asset|
          # transaction around batches of 200 could make faster?
          Asset.transaction do
            attacher = asset.file_attacher

            progress_bar.increment

            next unless attacher.derivatives.key?(:download_small)

            attacher.remove_derivative(:download_small, delete: true)

            asset.save(validate: false)

            # begin
            #   attacher.atomic_persist            # persist changes if attachment has not changed in the meantime
            # rescue Shrine::AttachmentChanged,    # attachment has changed
            #        ActiveRecord::RecordNotFound  # record has been deleted
            # end
          end
        end
      end
    end
  end
end
