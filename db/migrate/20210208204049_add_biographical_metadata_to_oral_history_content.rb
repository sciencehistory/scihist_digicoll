class AddBiographicalMetadataToOralHistoryContent < ActiveRecord::Migration[6.1]
  def change
    add_column :oral_history_content, :json_attributes, :jsonb, default: {}
  end
end