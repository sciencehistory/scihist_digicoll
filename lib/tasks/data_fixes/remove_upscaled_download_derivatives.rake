namespace :scihist do
  namespace :data_fixes do

    desc "Remove download_* derivatives larger than original, mistakenly created"
    task :remove_upscaled_download_derivatives => :environment do
      download_derivatives = [:download_large, :download_medium, :download_small]

      progress_bar = ProgressBar.create(total: Asset.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Asset.find_each do |asset|
        removed = []

        download_derivatives.each do |deriv_key|
          if asset.file_derivatives[deriv_key] && asset.width && asset.width <= asset.file_derivatives[deriv_key].width
            removed << deriv_key
          end
        end

        if removed.present?
          progress_bar.log("#{asset.friendlier_id} created #{asset.created_at}, width #{asset.width}, removing #{removed.join(',')}")

          # not sure why this is necessary, something weird going on we're not investigating now
          asset.restore_attributes

          asset.remove_derivatives(*removed)


        end

        progress_bar.increment
      end
    end
  end
end
