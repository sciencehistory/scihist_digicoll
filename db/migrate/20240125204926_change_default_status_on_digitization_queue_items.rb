class ChangeDefaultStatusOnDigitizationQueueItems < ActiveRecord::Migration[7.1]
  def change
    change_column_default :digitization_queue_items, :status, from: 'awaiting_dig_on_cart', to: 'awaiting_digitization'
  end
end
