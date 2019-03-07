class CreateAdminQueueItemComments < ActiveRecord::Migration[5.2]
  def change
    create_table :queue_item_comments do |t|
      t.belongs_to :digitization_queue_item, null: false, foreign_key: true
      t.belongs_to :user, null: true

      t.text :text

      t.boolean :system_action

      t.timestamps
    end
  end
end
