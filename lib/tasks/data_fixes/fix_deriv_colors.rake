namespace :scihist do
  namespace :data_fixes do
    task :fix_deriv_colors => [:environment] do
      scope = Asset.where("file_data -> 'metadata' ->> 'mime_type' like 'image/%'")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_each do |asset|
        if FixDerivColorsJob.needed_derivs(asset).present? || FixDerivColorsJob.needed_dzi?(asset)
          FixDerivColorsJob.perform_later(asset)
        end
        progress_bar.increment
      end
    end
  end
end
