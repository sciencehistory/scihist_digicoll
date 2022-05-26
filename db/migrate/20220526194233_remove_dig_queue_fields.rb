class RemoveDigQueueFields < ActiveRecord::Migration[6.1]
  def change
    remove_column :digitization_queue_items, :materials
    remove_column :digitization_queue_items, :instructions
  end
end
