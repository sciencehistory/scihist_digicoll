class AddDeviseColumnsToPatrons < ActiveRecord::Migration[8.1]
  def change
    add_column :oral_history_requester_emails, :remember_created_at, :datetime
    # secret for session and remember-me cookies, since patrons have no password
    add_column :oral_history_requester_emails, :session_token, :uuid, null: false, default: -> { "gen_random_uuid()" }
  end
end
