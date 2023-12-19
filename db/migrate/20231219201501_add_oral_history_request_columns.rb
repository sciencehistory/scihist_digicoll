class AddOralHistoryRequestColumns < ActiveRecord::Migration[7.1]
  def change
    add_column :oral_history_access_requests, :delivery_status_changed_at, :datetime
    add_column :oral_history_access_requests, :notes_from_staff, :text
  end
end
