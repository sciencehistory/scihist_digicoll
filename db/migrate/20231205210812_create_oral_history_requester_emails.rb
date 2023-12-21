class CreateOralHistoryRequesterEmails < ActiveRecord::Migration[7.1]
  def change
    create_table :oral_history_requester_emails do |t|
      t.string :email, null: false

      t.timestamps
    end

    add_index :oral_history_requester_emails, :email, unique: true

    add_reference :oral_history_access_requests, :oral_history_requester_email, foreign_key: { to_table: :oral_history_requester_emails }
  end
end
