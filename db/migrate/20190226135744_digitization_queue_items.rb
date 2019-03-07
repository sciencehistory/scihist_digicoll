class DigitizationQueueItems < ActiveRecord::Migration[5.2]
  def change
    create_table :digitization_queue_items do |t|
      t.string :title

      t.string :collecting_area

      t.string :bib_number
      t.string :location # call number etc
      t.string :accession_number
      t.string :museum_object_id
      t.string :box
      t.string :folder

      t.string :dimensions
      t.string :materials

      t.text :scope # number of components
      t.text :instructions # staging notes/handling issues
      t.text :additional_notes

      t.string :copyright_status

      t.string :status, default: "awaiting_dig_on_cart" # workflow status
      t.datetime :status_changed_at # record last status change

      t.timestamps null: false
    end
  end
end
