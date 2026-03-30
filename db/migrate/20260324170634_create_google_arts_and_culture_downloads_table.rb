class CreateGoogleArtsAndCultureDownloadsTable < ActiveRecord::Migration[8.1]
  def change
    create_table :google_arts_and_culture_downloads do |t|
      t.timestamps
      t.references :user, null: false, type: :bigint, foreign_key: { to_table: :users }

      t.string :status, null: false, default: "in_progress"
      #t.string :inputs_checksum, null: false
      t.text   :error_info

      t.integer :progress
      t.integer :progress_total

      t.jsonb :file_data
    end
  end

  # To ensure unique work/deriv_type pair, important for our concurrency safety
  # to make surre we atomically mark one as in progress.
  #add_index :on_demand_derivatives, [:work_id, :deriv_type], unique: true

end
