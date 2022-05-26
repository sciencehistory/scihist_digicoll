class AddColumnsToDigQueueItem < ActiveRecord::Migration[6.1]
  def change
    add_column :digitization_queue_items, :deadline, :date
    add_column :digitization_queue_items, :is_digital_collections, :boolean
    add_column :digitization_queue_items, :is_rights_and_reproduction, :boolean
  end
end
