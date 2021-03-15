class KitheModelRole < ActiveRecord::Migration[6.1]
  def change
    add_column :kithe_models, :role, :string
  end
end
