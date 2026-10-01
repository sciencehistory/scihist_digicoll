require 'http'
require 'csv'

namespace :scihist do
  namespace :data_fixes do

    desc """
      Update rights and rights holder values in Works as specified in data sheet
    """
    task :batch_update_rights => :environment do
      csv_url = ENV['DATA_CSV_URL'] || "https://docs.google.com/spreadsheets/d/1yRVB9b_C_7rEl8YuwF1o5id6a8FidfD1A4wrFpMq7dM/export?format=csv"

      csv_body = HTTP.follow.get(csv_url).to_s

      csv = CSV.parse(csv_body, headers: true)

      progress_bar = ProgressBar.create(total: csv.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      skipped = 0
      Kithe::Indexable.index_with(batching: true) do
        csv.each do |row|
          friendlier_id = row['Link'].split("/").last
          rights_statement_label = row['Rights Status']
          rights_holder = row['Rights Holder']


          if rights_statement_label.downcase == "public domain"
            # we use a different internal value
            rights_statement_label = "Public Domain Mark 1.0"
          end
          rights_uri = RightsTerm.terms_by_id.find { |id, info| info.label.downcase == rights_statement_label.downcase }&.first
          raise "Could not find id for rights label #{rights_statement_label}" unless rights_uri

          work = Work.find_by_friendlier_id(friendlier_id)

          if work
            work.rights = rights_uri
            work.rights_holder = rights_holder if rights_holder.present?
            work.save!
          else
            skipped +=1
            progress_bar.log("Could not find work #{friendlier_id}")
          end


          progress_bar.increment
        end
      end

      if skipped != 0
        puts "\n\n SKIPPED #{skipped} records"
      end
    end
  end
end

