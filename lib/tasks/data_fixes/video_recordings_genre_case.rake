namespace :scihist do
  namespace :data_fixes do
    desc "Change genre 'Video Recordings' to 'Video recordings' with a bulk SQL update"
    task :video_recordings_genre_case => :environment do
      Work.where("json_attributes -> 'genre' ? 'Video Recordings'").update_all(%q{
        json_attributes = jsonb_set(
          json_attributes,
          '{genre}',
          replace((json_attributes -> 'genre')::text, '"Video Recordings"', '"Video recordings"')::jsonb
        )
      })

      # SQL update bypasses callbacks, so reindex to Solr
      Kithe::Indexable.index_with(batching: true) do
        Work.where("json_attributes -> 'genre' ? 'Video recordings'").find_each do |work|
          work.update_index
        rescue StandardError => e
          puts "Could not reindex #{work.friendlier_id}: #{e.class}: #{e.message}"
        end
      end
    end
  end
end
