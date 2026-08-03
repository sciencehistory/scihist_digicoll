namespace :scihist do
  namespace :data_fixes do
    desc """
      An old version of marcel mis-identified our low-bitrate opus-in-ogg audio
      files as audio/opus. marcel now correctly identifies these as audio/ogg.
      Fix the mime_type already stored in file_data -- for the original file itself,
      as well as for any derivative (under any key, including old/renamed derivative
      keys) -- still recorded as audio/opus.

      Done as two plain SQL UPDATEs rather than fetching/re-saving each record.

      Written by Claude.
    """
    task :fix_opus_mime_type => [:environment] do
      original_count = Asset.where(%q{
        file_data -> 'metadata' ->> 'mime_type' = 'audio/opus'
      }).update_all(%q{
        file_data = jsonb_set(file_data, '{metadata,mime_type}', '"audio/ogg"')
      })
      puts "Fixed original file mime_type on #{original_count} asset(s)"

      derivative_count = Asset.where(%q{
        EXISTS (
          SELECT 1 FROM jsonb_each(file_data -> 'derivatives') AS d(key, value)
          WHERE d.value #>> '{metadata,mime_type}' = 'audio/opus'
        )
      }).update_all(%q{
        file_data = jsonb_set(
          file_data,
          '{derivatives}',
          (
            SELECT jsonb_object_agg(
              d.key,
              CASE WHEN d.value #>> '{metadata,mime_type}' = 'audio/opus'
                   THEN jsonb_set(d.value, '{metadata,mime_type}', '"audio/ogg"')
                   ELSE d.value
              END
            )
            FROM jsonb_each(file_data -> 'derivatives') AS d(key, value)
          )
        )
      })
      puts "Fixed derivative mime_type on #{derivative_count} asset(s)"
    end
  end
end
