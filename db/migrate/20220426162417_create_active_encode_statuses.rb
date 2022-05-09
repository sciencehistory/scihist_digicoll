class CreateActiveEncodeStatuses < ActiveRecord::Migration[6.1]
  def change
    create_table :active_encode_statuses do |t|
      t.string :active_encode_id
      t.uuid :asset_id
      t.string :state
      t.text :encode_error
      t.integer :percent_complete
      t.string :hls_master_playlist_s3_url

      t.timestamps
    end
    add_index :active_encode_statuses, :active_encode_id
    add_index :active_encode_statuses, :asset_id
    add_index :active_encode_statuses, :state
  end
end
