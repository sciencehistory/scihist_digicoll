class AddQueueItemIdToModels < ActiveRecord::Migration[5.2]
  def change
    add_column :kithe_models, :digitization_queue_item_id, :bigint
    add_foreign_key :kithe_models, :digitization_queue_items, null: true
  end
end
