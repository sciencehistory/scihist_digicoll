class AddPatronCyphertextToRAndRItems < ActiveRecord::Migration[5.2]
  def change
    add_column :r_and_r_items, :patron_name_ciphertext,  :text
    add_column :r_and_r_items, :patron_email_ciphertext, :text

    remove_column :r_and_r_items, :patron_name
    remove_column :r_and_r_items, :patron_email
  end
end
