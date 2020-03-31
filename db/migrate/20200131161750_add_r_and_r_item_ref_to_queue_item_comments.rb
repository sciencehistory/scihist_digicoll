class AddRAndRItemRefToQueueItemComments < ActiveRecord::Migration[5.2]
  def change
    add_column :queue_item_comments, :r_and_r_item_id, :bigint, null:true
    add_foreign_key :queue_item_comments, :r_and_r_items, null: true
    change_column_null :queue_item_comments, :digitization_queue_item_id, true
  end
end
