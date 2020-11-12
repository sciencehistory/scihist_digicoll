class OralHistoryDeliveryJob < ApplicationJob
  def perform(request)
    OralHistoryDeliveryMailer.
      with(request: request).
      oral_history_delivery_email
      .deliver_now
  end
end