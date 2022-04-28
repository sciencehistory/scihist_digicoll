class RefreshActiveEncodeStatusJob < ApplicationJob
  # @param active_encode_status [ActiveEncodeStatus]
  def perform(active_encode_status)
    active_encode_status.refresh_from_aws
  end
end
