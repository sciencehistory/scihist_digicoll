namespace :scihist do
  namespace :data_fixes do

    desc """
      Unescape the double-escaped JSON hls_playlist_file_data. Idempotent, safe to run multiple times.
    """
    task :unescape_hls_playlist_file_data => :environment do
      Asset.where("json_attributes->'hls_playlist_file_data' is not null").pluck("id").each do |pk|
        # clever code to un-escape jsbon in SQL,
        # https://dev.to/mrmurphy/so-you-put-an-escaped-string-into-a-json-column-2n67
        #
        # which we need to use with somewhat confusing PG `jsonb_set`,
        # since we aren't on PG14 yet that would support hash-index-like setting.
        Asset.connection.execute(
          <<-EOS
            UPDATE kithe_models
            SET json_attributes = jsonb_set(json_attributes, '{hls_playlist_file_data}',
                                              (json_attributes->'hls_playlist_file_data' #>> '{}')::jsonb
                                            )
            WHERE  id = '#{pk}'
          EOS
        )
      end
    end
  end
end
