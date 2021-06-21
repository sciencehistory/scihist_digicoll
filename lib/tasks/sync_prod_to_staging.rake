namespace :scihist do
  desc "Sync prod to staging. Assumes that you have credentials for both prod and staging, and at least read access to the backup s3 bucket."
  # bundle exec rake scihist:sync_prod_to_staging
  task :sync_prod_to_staging do
    BACKUP_BUCKET="chf-hydra-backup"
    BACKUP_FILENAME="heroku-scihist-digicoll-backup.sql"
    BACKUP_REGION="us-west-2"
    STAGING_APP_NAME="scihist-digicoll-staging"

    abort 'This task should only be used in development' if ['staging', 'production'].include? ScihistDigicoll::Env.lookup(:service_level)
    cmd = TTY::Command.new
    begin
      cmd.run("heroku", "maintenance:on", "--app", STAGING_APP_NAME)
      aws_client = Aws::S3::Client.new(
          access_key_id:     ScihistDigicoll::Env.lookup(:aws_access_key_id),
          secret_access_key: ScihistDigicoll::Env.lookup(:aws_secret_access_key),
          region:            BACKUP_REGION
        )
      aws_bucket = Aws::S3::Bucket.new(name: BACKUP_BUCKET, client: aws_client)
      aws_object = aws_bucket.object("PGSql/#{BACKUP_FILENAME}.gz")
      aws_object.download_file("#{BACKUP_FILENAME}.gz")
      cmd.run("gunzip", "--force", "#{BACKUP_FILENAME}.gz")
      abort("Backup database file not present") unless File.exist?(BACKUP_FILENAME)
      cmd.run("heroku", "pg:psql", "--app", STAGING_APP_NAME, in: BACKUP_FILENAME)
      Rake::Task["scihist:solr:reindex"].invoke("--app #{STAGING_APP_NAME}")
      Rake::Task["scihist:solr:delete_orphans"].invoke("--app #{STAGING_APP_NAME}")
    ensure
      cmd.run("heroku", "maintenance:off", "--app", "scihist-digicoll-staging")
      File.delete("heroku-scihist-digicoll-backup.sql")    if File.exist?(BACKUP_FILENAME)
      File.delete("heroku-scihist-digicoll-backup.sql.gz") if File.exist?("#{BACKUP_FILENAME}.gz")
    end
  end
end