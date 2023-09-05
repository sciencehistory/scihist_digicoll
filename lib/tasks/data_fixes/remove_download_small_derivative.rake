namespace :scihist do
  namespace :data_fixes do
    desc """
      Remove download_small derivative from all assets, remove from S3
    """
    task :remove_download_small_derivatives => :environment do
      progress_bar = ProgressBar.create(total: Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      # https://shrinerb.com/docs/changing-derivatives#removing-derivatives
      Asset.find_each do |asset|
        attacher = asset.file_attacher

        progress_bar.increment

        next unless attacher.derivatives.key?(:download_small)

        attacher.remove_derivative(:download_small, delete: true)

        begin
          attacher.atomic_persist            # persist changes if attachment has not changed in the meantime
        rescue Shrine::AttachmentChanged,    # attachment has changed
               ActiveRecord::RecordNotFound  # record has been deleted
        end
      end
    end
  end
end
