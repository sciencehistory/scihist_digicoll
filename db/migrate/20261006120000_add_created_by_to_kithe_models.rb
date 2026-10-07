class AddCreatedByToKitheModels < ActiveRecord::Migration[8.1]
  def change
    add_reference :kithe_models, :created_by, foreign_key: { to_table: :users }, null: true
  end
end
