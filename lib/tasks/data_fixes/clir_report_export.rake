namespace :scihist do
  namespace :data_fixes do
    desc "a report asked for by CLIR for Bredig project, as CSV"
    task :clir_asset_report => :environment do
      bredig_collection = Collection.find_by_friendlier_id("qfih5hl")

      csv_string = CSV.generate do |csv|
        bredig_collection.contains.order(created_at: :asc).find_each do |work|

          work.members.where(published: true).find_each do |asset|
            latest_fixity = asset.fixity_checks.order('created_at desc').first

            csv << [
              asset.original_filename,
              "https://digital.sciencehistory.org/downloads/orig/image/#{asset.friendlier_id}",
              "sha512:#{asset.sha512}",
              latest_fixity&.created_at&.iso8601
            ]
          end

        end
      end

      puts csv_string

    end
  end
end
