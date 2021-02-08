class OralHistoryAccessRequestDeliveryStatus < ActiveRecord::Migration[6.1]
  def change
    add_column :oral_history_access_requests, :delivery_status, :string, default: "pending"
  end
end
