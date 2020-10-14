class CreateAssetDerivativeStorageTypeReports < ActiveRecord::Migration[6.0]
  def change
    create_table :asset_derivative_storage_type_reports do |t|
      t.jsonb :data_for_report, default: {}
      t.timestamps
    end
  end
end