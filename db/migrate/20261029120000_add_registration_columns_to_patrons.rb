class AddRegistrationColumnsToPatrons < ActiveRecord::Migration[8.1]
  def change
    # same column name as devise :confirmable, in case we switch to it
    add_column :oral_history_requester_emails, :confirmed_at, :datetime

    add_column :oral_history_requester_emails, :name_ciphertext, :text
    add_column :oral_history_requester_emails, :institution_ciphertext, :text
    add_column :oral_history_requester_emails, :registration_reason_ciphertext, :text
  end
end
