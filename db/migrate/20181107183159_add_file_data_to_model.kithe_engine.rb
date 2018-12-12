# This migration comes from kithe_engine (originally 20181031190647)
class AddFileDataToModel < ActiveRecord::Migration[5.2]
  def change
    add_column :kithe_models, :file_data, :jsonb
  end
end
