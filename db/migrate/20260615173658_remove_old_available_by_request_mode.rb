class RemoveOldAvailableByRequestMode < ActiveRecord::Migration[8.1]
  def change
    remove_column :oral_history_content, :available_by_request_mode
    drop_enum :available_by_request_mode_type
  end
end
