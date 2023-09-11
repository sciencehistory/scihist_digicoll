namespace :scihist do
  namespace :data_fixes do
    desc "Migrate attr-json Asset#hocr to new separate derived_metadata_jsonb column"
    task :migrate_hocr_to_derived_metadata_jsonb => :environment do
      scope = Asset.where("json_attributes ->> 'hocr' is not null")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      # try committing in a transaction of batches of 100, maybe faster?
      scope.find_in_batches(batch_size: 100) do |batch|
        Asset.transaction do
          batch.each do |asset|
            asset.hocr = asset.json_attributes["hocr"]
            asset.json_attributes.delete("hocr")
            asset.save!

            progress_bar.increment
          end
        end
      end
    end
  end
end
