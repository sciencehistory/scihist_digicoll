class CreateGoogleArtsAndCultureDownloadsTable < ActiveRecord::Migration[8.1]
  def change
    create_table :google_arts_and_culture_downloads do |t|
      t.timestamps
      t.references :user, null: false, type: :bigint, foreign_key: { to_table: :users }

      t.string :status, null: false, default: "in_progress"

      t.text   :error_info
      t.text   :user_notes

      t.integer :progress
      t.integer :progress_total

      t.jsonb :file_data
    end
  end
end
