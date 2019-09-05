class CreateFixityChecks < ActiveRecord::Migration[5.2]
  def change
    create_table :fixity_checks do |t|
      t.references :asset, null: false, type: :uuid, foreign_key: { to_table: :kithe_models }
      t.boolean :passed
      t.string :expected_result
      t.string :actual_result
      t.string :checked_uri
      t.timestamps
    end
    add_index :fixity_checks, :checked_uri
    add_index :fixity_checks, [:asset_id, :checked_uri], name: 'by_asset_and_checked_uri', order: {created_at: "DESC" }
  end
end