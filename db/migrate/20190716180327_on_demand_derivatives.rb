class OnDemandDerivatives < ActiveRecord::Migration[5.2]
  def change
    create_table :on_demand_derivatives do |t|
      t.references :work, null: false, type: :uuid, foreign_key: { to_table: :kithe_models }

      t.string :deriv_type, null: false
      t.string :status, null: false, default: "in_progress"
      t.string :inputs_checksum, null: false
      t.text :error_info

      t.integer :progress
      t.integer :progress_total

      t.timestamps
    end

    # To ensure unique work/deriv_type pair, important for our concurrency safety
    # to make surre we atomically mark one as in progress.
    add_index :on_demand_derivatives, [:work_id, :deriv_type], unique: true
  end
end
