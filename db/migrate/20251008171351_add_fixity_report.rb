class AddFixityReport < ActiveRecord::Migration[8.0]
  def change
    create_table :fixity_reports do |t|
      t.jsonb :data_for_report, default: {}
      t.timestamps
    end
  end
end
