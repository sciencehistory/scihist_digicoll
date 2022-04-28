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
      percent_complete: active_encode_result.percent_complete
    )
  end
end
