class AddLastPublishedByToKitheModels < ActiveRecord::Migration[8.1]
  def change
    add_reference :kithe_models, :last_published_by, foreign_key: { to_table: :users }, null: true
  end
end
