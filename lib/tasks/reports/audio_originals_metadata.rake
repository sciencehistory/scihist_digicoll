namespace :scihist do
  namespace :reports do
    desc """Export audio characterization metadata to stdout.
      bundle exec rake scihist:reports:audio_originals_metadata  > metadata.csv
    """
    task :audio_originals_metadata => :environment do
      csv_string = CSV.generate do |csv|
        csv << [
          'friendlier_id',
          'size',
          'bitrate',
          'filename',
          'mime_type',
          'audio_codec',
          'audio_channels',
          'duration_seconds',
          'audio_sample_rate',
          'audio_channel_layout',
        ]
        Kithe::Indexable.index_with(batching: true) do
          Asset.find_each(batch_size: 10) do |a|
            next unless a.content_type && (a.content_type.start_with?("audio")) && a.stored?
            m = a.file.metadata
            csv << [
              a.friendlier_id,
              m['size'],
              m['bitrate'],
              m['filename'],
              m['mime_type'],
              m['audio_codec'],
              m['audio_channels'],
              m['duration_seconds'],
              m['audio_sample_rate'],
              m['audio_channel_layout'],
            ]
          end
        end
      end
      puts csv_string
    end
  end
end
