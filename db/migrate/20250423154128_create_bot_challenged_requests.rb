class CreateBotChallengedRequests < ActiveRecord::Migration[8.0]
  def change
    create_table :bot_challenged_requests do |t|
      t.string :path
      t.string :request_id
      t.string :client_ip
      t.string :user_agent
      t.string :normalized_user_agent
      t.jsonb :headers

      # no updated_at, won't mutate
      t.datetime :created_at, null: false
    end

    add_index :bot_challenged_requests, :client_ip
    add_index :bot_challenged_requests, :request_id
  end
end
