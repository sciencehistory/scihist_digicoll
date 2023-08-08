namespace :scihist do
  namespace :reports do
    desc """Export metadata to stdout for some data visualizations work.
      See https://github.com/sciencehistory/scihist_digicoll/issues/1927 .
      bundle exec rake scihist:reports:clir_report_august_2023
    """
    task :clir_report_august_2023 => :environment do
      include Rails.application.routes.url_helpers

      bredig_collection =  Collection.find_by_friendlier_id('qfih5hl')
      base_url = ScihistDigicoll::Env.lookup!(:app_url_base)

      def sample_size = 600
        
      csv_string = CSV.generate do |csv|
        csv << [
          'Admin URL',
          'Download URL',
          'Internal filename',
          'Filename as downloaded',
          'SHA 512 checksum',
          'Date file verified',
        ]
        i = 0
        Kithe::Indexable.index_with(batching: true) do
          bredig_collection.contains.find_each do |work|
            asset = work.members.sample
            break if (i = i + 1) > sample_size
            
            csv << ([
              # 'admin_url',
              "#{base_url}/admin/asset_files/#{asset.friendlier_id}",

              # 'download_url',
              "#{base_url}#{download_path(asset.file_category, asset)}",

              # 'filename_1',
              asset.file.metadata['filename'],

              # 'filename_2',
              DownloadFilenameHelper.filename_for_asset(asset),

              # 'checksum',
              asset.file.metadata['sha512'],

              #Fixity check date
              check = asset.fixity_checks.last.created_at,

            ])
          end
        end
      end
      puts csv_string
    end
  end
end
