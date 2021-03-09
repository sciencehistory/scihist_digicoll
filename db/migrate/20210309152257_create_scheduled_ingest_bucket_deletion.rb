class CreateScheduledIngestBucketDeletion < ActiveRecord::Migration[6.1]
  def change
    create_table :scheduled_ingest_bucket_deletions do |t|
      t.string :path
      t.datetime :delete_after
      t.references :asset, null: true, type: :uuid

      t.timestamps
    end
  end
end
