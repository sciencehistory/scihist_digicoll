namespace :scihist do
  namespace :reports do
    desc """Export metadata to stdout for the final CLIR Report (summer 2023).
      See https://github.com/sciencehistory/scihist_digicoll/issues/2299 .
      bundle exec rake scihist:reports:clir_report_august_2023

      SPEC: The filenames of a representative sampling of access files created
      through your project. (600 files for a 24-month project). Include the
      file extensions (.jpg, .jpeg, .tiff, .mp3, .mp4, etc.) as part of the
      filenames.
          NOTES:
            Filenames: I'm providing both the friendly filename saved on
              your computer when you download it, *and* the internal
              filename here (which is the filename as ingested).
              I would argue for using the latter since we're looking
              at this from a preservation context.
            Representative sample: I picked one image at random from the
              first 600 works that came up in the Bredig collection.
              We could of course change this recipe, but it seems
              'representative' enough.

      SPEC: The full URL/URI (including http:// or https://) for the location of
      the listed files on your main access system. Note this should be the
      URL/URI for the file itself and not for the metadata record
      associated with the file.
          NOTE: I'm using the download URL for this. This is, after a manner
            of speaking, the URL for the file itself: if you visit that URL,
            your browser will download the file.

      SPEC: If you have generated a checksum to monitor the integrity of the
      files, enter the checksum value into the column labeled 'CHECKSUM'.
          NOTE: I'm using the SHA512 checksum. We keep several, but that's
            the one we check.

      SPEC: Enter the date you last verified the availability of each file on your
      main access system.
          NOTE: I'm using the date of the latest checksum. Why?
            In the process of calculating a checksum, we download the
              entire contents of the file from storage.
            If a file can be downloaded from s3 in this manner,
              we consider it 'available';
            If a file passed its fixity check, the file was
              a fortiori 'available' at the time of the check.

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
              # 'Admin URL',
              "#{base_url}/admin/asset_files/#{asset.friendlier_id}",
              # 'Download URL',
              "#{base_url}#{download_path(asset.file_category, asset)}",
              # 'Internal filename',
              asset.file.metadata['filename'],
              # 'Filename as downloaded',
              DownloadFilenameHelper.filename_for_asset(asset),
              # 'SHA 512 checksum',
              asset.file.metadata['sha512'],
              # 'Date file verified',
              check = asset.fixity_checks.last.created_at,
            ])
          end
        end
      end
      puts csv_string
    end
  end
end
