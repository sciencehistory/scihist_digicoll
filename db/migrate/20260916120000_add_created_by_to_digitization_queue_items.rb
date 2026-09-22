class AddCreatedByToDigitizationQueueItems < ActiveRecord::Migration[8.1]
  def change
    add_reference :digitization_queue_items, :created_by, foreign_key: { to_table: :users }, null: true
  end
end
