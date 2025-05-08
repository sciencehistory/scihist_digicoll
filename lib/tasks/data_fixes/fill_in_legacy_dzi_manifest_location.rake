namespace :scihist do
  namespace :data_fixes do
    task :fill_in_legacy_dzi_manifest_location => :environment do
      scope = Asset.where("file_data -> 'metadata' ->> 'mime_type' like 'image/%'")

      if ENV['ASSET_ID']
        scope = scope.where(friendlier_id: ENV['ASSET_ID'])
      end

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_in_batches(batch_size: 100) do |batch|
        Asset.transaction do
          batch.each do |asset|
            Kithe::Indexable.index_with(batching: true) do
              legacy_manifest_location = "#{asset.id}/md5_#{asset.md5}.dzi"

              if asset.json_attributes["dzi_manifest_file_data"].blank?
                asset.json_attributes["dzi_manifest_file_data"] = {
                  "id" => legacy_manifest_location,
                  "storage" => "dzi_storage"
                }

                asset.save!
              end

              progress_bar.increment
            end
          end
        end
      end
    end
  end
end
