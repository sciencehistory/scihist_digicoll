namespace :scihist do
  desc "Delete files from ingest_bucket that have been scheduled"
  task :scheduled_ingest_bucket_delete => :environment do
    ScheduledIngestBucketDeletion.where("delete_after < ?", Time.now).find_each do |scheduled|
        client = Aws::S3::Client.new(
          access_key_id:     ScihistDigicoll::Env.lookup(:aws_access_key_id),
          secret_access_key: ScihistDigicoll::Env.lookup(:aws_secret_access_key),
          region:            ScihistDigicoll::Env.lookup(:aws_region)
        )
        bucket = Aws::S3::Bucket.new(name: ScihistDigicoll::Env.lookup!(:ingest_bucket), client: client)

        bucket.object(scheduled.path).delete

        scheduled.destroy!
    end
  end
end
