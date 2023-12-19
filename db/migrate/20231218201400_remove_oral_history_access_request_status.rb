class RemoveOralHistoryAccessRequestStatus < ActiveRecord::Migration[7.1]
  def change
    remove_column :oral_history_access_requests, :status, :string
  remove_column :oral_history_access_requests, :notes, :text
  end
end
