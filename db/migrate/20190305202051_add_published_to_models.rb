class AddPublishedToModels < ActiveRecord::Migration[5.2]
  def change
    add_column :kithe_models, :published, :boolean
  end
end
