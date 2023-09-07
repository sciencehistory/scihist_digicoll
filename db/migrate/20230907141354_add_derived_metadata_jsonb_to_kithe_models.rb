class AddDerivedMetadataJsonbToKitheModels < ActiveRecord::Migration[7.0]
  def change
    add_column :kithe_models, :derived_metadata_jsonb, :jsonb
  end
end
