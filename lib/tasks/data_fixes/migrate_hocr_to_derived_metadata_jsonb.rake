namespace :scihist do
  namespace :data_fixes do
    desc "Migrate attr-json Asset#hocr to new separate derived_metadata_jsonb column"
    task :migrate_hocr_to_derived_metadata_jsonb => :environment do
      scope = Asset.where("json_attributes ->> 'hocr' is not null")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_each do |asset|
        asset.hocr = asset.json_attributes["hocr"]
        asset.json_attributes.delete("hocr")
        asset.save!

        progress_bar.increment
      end
    end
  end
end
