# Note the active_encode_id is also exactly the MediaConvert job ID in AWS,
# if we're using MediaConvert, as we are.
class ActiveEncodeStatus < ApplicationRecord
  belongs_to :asset

  enum state: [ "running", "cancelled", "failed", "completed" ].map {|v| [v, v]}.to_h

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
  def refresh_from_aws
    active_encode_result = ActiveEncode::Base.find(self.active_encode_id)

    # active_encode let's us recognize the master playlist just cause
    # it has no height/width set? OK, fine.
    master_playlist = active_encode_result.output.find { |o| o.height.nil? }

    # update updated_at even if no other state changes, to record the refresh
    update!(
      updated_at: Time.now,
      state: active_encode_result.state,
      encode_error: active_encode_result.errors.join("\n; ").presence,
      percent_complete: active_encode_result.percent_complete,
      hls_master_playlist_s3_url: master_playlist&.url
    )

    if active_encode_result.state == :completed
      update_asset_on_completed
    end
  end

  def update_asset_on_completed
    # let the asset know we have an HLS!
    asset.hls_playlist_file_as_s3 = self.hls_master_playlist_s3_url
    asset.save!
  end
end
