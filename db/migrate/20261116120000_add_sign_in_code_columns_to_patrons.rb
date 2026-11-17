class AddSignInCodeColumnsToPatrons < ActiveRecord::Migration[8.1]
  def change
    add_column :oral_history_requester_emails, :sign_in_code_digest, :string
    add_column :oral_history_requester_emails, :sign_in_code_sent_at, :datetime
    add_column :oral_history_requester_emails, :sign_in_code_failed_attempts, :integer, default: 0, null: false
  end
end
