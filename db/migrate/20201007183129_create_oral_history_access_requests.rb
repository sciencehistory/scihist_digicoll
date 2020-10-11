class CreateOralHistoryAccessRequests < ActiveRecord::Migration[6.0]
  def change
    create_table :oral_history_access_requests do |t|
      t.references :work, type: :uuid, foreign_key: { to_table: :kithe_models }, null: false
      t.text :patron_name_ciphertext,          null: true
      t.text :patron_email_ciphertext,         null: true
      t.text :patron_institution_ciphertext
      t.text :intended_use_ciphertext,         null: true
      t.string :status
      t.text :notes
      t.timestamps
    end
  end
end
