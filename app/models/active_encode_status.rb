# Note the active_encode_id is also exactly the MediaConvert job ID in AWS,
# if we're using MediaConvert, as we are.
class ActiveEncodeStatus < ApplicationRecord
  belongs_to :asset, optional: true

  enum :state, [ "running", "cancelled", "failed", "completed" ].map {|v| [v, v]}.to_h

  def self.create_from!(asset:, active_encode_result:)
    ActiveEncodeStatus.create!(
      asset: asset,
      active_encode_id: active_encode_result.id,
      state: active_encode_result.state,
      encode_error: active_encode_result.errors.join("\n; ").presence,
      percent_complete: active_encode_result.percent_complete,
    )
  end

  # Refreshes status from AWS MediaConvert. Will raise Aws::MediaConvert::Errors::NotFoundException
  # if it's more than 90 days past job creation! AWS holds em for 90 days.
  #
  # Will raise ActiveEncodeStatus::EncodeFailedError on failed status
  def refresh_from_aws
    active_encode_result = ActiveEncode::Base.find(self.active_encode_id)

    # active_encode makes it difficult to recognize master playlist, the label
    # matching our base name currently should do it. Other ones that aren't mater
    # might be #{OUTPUT_BASE_NAME}_low.m3u8 or #{OUTPUT_BASE_NAME}_high.m3u8 etc.
    master_playlist = active_encode_result.output.find { |o| o.label == "#{CreateHlsMediaconvertJobService::OUTPUT_BASE_NAME}.m3u8" }

    # update updated_at even if no other state changes, to record the refresh
    update!(
      updated_at: Time.now,
      state: active_encode_result.state,
      encode_error: active_encode_result.errors.join("\n; ").presence,
      percent_complete: active_encode_result.percent_complete,
      hls_master_playlist_s3_url: master_playlist&.url
    )

    if active_encode_result.state == :failed
      raise EncodeFailedError.new("Asset: #{asset&.friendlier_id}, #{self.encode_error}")
    end

    if active_encode_result.state == :completed
      update_asset_on_completed
    end
  end

  def update_asset_on_completed
    if asset.nil?
      clean_up_leftover_files
    else
      # let the asset know we have an HLS!
      asset.hls_playlist_file_as_s3 = self.hls_master_playlist_s3_url
      asset.save!
      # trigger exception if asset is actually gone.
      asset.reload
    end
  rescue ActiveRecord::RecordNotFound => e
    clean_up_leftover_files
  end

  # the asset was deleted semi-concurrently?  Let's clean up the files that were
  # created...
  def clean_up_leftover_files
    storage = Shrine.storages[:video_derivatives]

    if self.hls_master_playlist_s3_url
      Rails.logger.error("Deleting leftover HLS files for apparently missing asset ID: #{asset_id}, files at: #{hls_master_playlist_s3_url}")

      uri = URI.parse(self.hls_master_playlist_s3_url)
      path = uri.path.delete_prefix("/")
      containing_path = File.dirname(path).chomp("/").concat("/")

      # normalize to storage id for storage prefix
      if storage.respond_to?(:prefix) && storage.prefix.present?
        containing_path = containing_path.delete_prefix("#{storage.prefix.to_s}/")
      end

      storage.delete_prefixed(containing_path)
    end
  end

  class EncodeFailedError < StandardError ; end
end
