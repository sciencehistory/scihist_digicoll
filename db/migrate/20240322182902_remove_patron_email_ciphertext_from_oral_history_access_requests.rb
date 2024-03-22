class RemovePatronEmailCiphertextFromOralHistoryAccessRequests < ActiveRecord::Migration[7.1]
  def change
    remove_column      :oral_history_access_requests, :patron_email_ciphertext, :text
    change_column_null :oral_history_access_requests, :oral_history_requester_email_id, false
  end
end
