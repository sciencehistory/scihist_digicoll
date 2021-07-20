# If we're promoting a shrine cache file using remote_url storage, and
# the file is from our ingest_bucket, we add a record to this table
# with a `delete_after` timestamp, so we can run a scheduled task
# to delete stuff from the ingest bucket.
class ScheduledIngestBucketDeletion < ApplicationRecord
  DELETE_AFTER_WINDOW = 24.hours

  belongs_to :asset
end
