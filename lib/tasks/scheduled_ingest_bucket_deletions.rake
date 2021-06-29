namespace :scihist do
  desc "Delete files from ingest_bucket that have been scheduled"
  task :scheduled_ingest_bucket_delete => :environment do
    client = Aws::S3::Client.new(
      access_key_id:     ScihistDigicoll::Env.lookup(:aws_access_key_id),
      secret_access_key: ScihistDigicoll::Env.lookup(:aws_secret_access_key),
      region:            ScihistDigicoll::Env.lookup(:aws_region)
    )
    bucket = Aws::S3::Bucket.new(name: ScihistDigicoll::Env.lookup!(:ingest_bucket), client: client)

    ScheduledIngestBucketDeletion.where("delete_after < ?", Time.now).find_each do |scheduled|
        bucket.object(scheduled.path).delete
        scheduled.destroy!
    end

    # now delete ALL placeholder directory objects, they aren't needed for anything,
    # they just wind up sticking around after we've deleted their contents. But it's
    # fine to delete placeholder obj when contents are still there too.
    bucket.objects.each do |obj|
      if obj.key.end_with?('/') && obj.size == 0
        obj.delete
      end
    end
  end
end
