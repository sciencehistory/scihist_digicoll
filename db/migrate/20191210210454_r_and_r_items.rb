class RAndRItems < ActiveRecord::Migration[5.2]
  def change
    create_table :r_and_r_items do |t|
      t.string :title

      t.string :curator
      t.string :collecting_area
      t.string :patron_name
      t.string :patron_email

      t.string :bib_number
      t.string :location # call number etc
      t.string :accession_number
      t.string :museum_object_id
      t.string :box
      t.string :folder
      t.string :dimensions
      t.string :materials
      t.string :copyright_status

      t.boolean :is_destined_for_ingest # into the digital collections.
      t.text :instructions # staging notes/handling issues
      t.text :scope # number of components
      t.text :additional_pages_to_ingest
      t.text :additional_notes

      t.string :status, default: "awaiting_dig_on_cart" # workflow status
      t.datetime :status_changed_at # record last status change
      t.datetime :deadline
      t.datetime :date_files_sent

      t.timestamps null: false
    end
  end
end