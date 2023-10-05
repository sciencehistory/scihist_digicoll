class AddFileDataGin < ActiveRecord::Migration[7.0]
  def change
    add_index :kithe_models, :file_data, using: "gin"
  end
end
