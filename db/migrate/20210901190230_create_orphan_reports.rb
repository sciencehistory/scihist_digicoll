class CreateOrphanReports < ActiveRecord::Migration[6.1]
  def change
    create_table :orphan_reports do |t|
      t.jsonb :data_for_report, default: {}
      t.timestamps
    end
  end
end
