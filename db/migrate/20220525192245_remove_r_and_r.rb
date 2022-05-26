class RemoveRAndR < ActiveRecord::Migration[6.1]

  # trying to make this migration reversible by supplying all the info to reverse it and
  # re-create deleted things!
  def change
    remove_foreign_key :digitization_queue_items, :r_and_r_items
    remove_column :digitization_queue_items, :r_and_r_item_id, :bigint

    remove_foreign_key "queue_item_comments", "r_and_r_items"
    remove_column :queue_item_comments, :r_and_r_item_id, :bigint

    change_column_null :queue_item_comments, :digitization_queue_item_id, false

    drop_table :r_and_r_items do |t|
      t.string "title"
      t.string "curator"
      t.string "collecting_area"
      t.string "bib_number"
      t.string "location"
      t.string "accession_number"
      t.string "museum_object_id"
      t.string "box"
      t.string "folder"
      t.string "dimensions"
      t.string "materials"
      t.string "copyright_status"
      t.boolean "is_destined_for_ingest"
      t.boolean "copyright_research_still_needed", default: true
      t.text "instructions"
      t.text "scope"
      t.text "additional_pages_to_ingest"
      t.text "additional_notes"
      t.string "status", default: "awaiting_dig_on_cart"
      t.datetime "status_changed_at"
      t.datetime "deadline"
      t.datetime "date_files_sent"
      t.datetime "created_at", null: false
      t.datetime "updated_at", null: false
      t.text "patron_name_ciphertext"
      t.text "patron_email_ciphertext"
    end
  end
end
