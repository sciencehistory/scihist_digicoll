namespace :scihist do
  desc "Take the latest database backup from s3," +
  " and replace the staging database with it." +
  " Assumes: a) at least read access to the backup s3 bucket," +
  " and b) heroku credentials for the staging app." +

  " bundle exec rake scihist:sync_prod_to_staging" +

  " ENV variables you can set: BACKUP_REGION; BACKUP_FOLDER; " +
  " BACKUP_BUCKET; BACKUP_FILENAME; STAGING_APP_NAME; and UNZIP_CMD"
  task :sync_prod_to_staging => :environment do
    BACKUP_BUCKET    = ENV['BACKUP_BUCKET']     || "chf-hydra-backup"
    BACKUP_FOLDER    = ENV['BACKUP_FOLDER']     || "PGSql"
    BACKUP_FILENAME  = ENV['BACKUP_FILENAME']   || "heroku-scihist-digicoll-backup.sql"
    BACKUP_REGION    = ENV['BACKUP_REGION']     || "us-west-2"
    STAGING_APP_NAME = ENV['STAGING_APP_NAME']  || "scihist-digicoll-staging"
    UNZIP_CMD        = ENV['UNZIP_CMD']         || "gunzip --force"

    if ['staging', 'production'].include? ScihistDigicoll::Env.lookup(:service_level)
      abort 'This task should only be used in development.'
    end
    cmd = TTY::Command.new
    begin
      cmd.run("heroku maintenance:on --app", STAGING_APP_NAME)
      backup_location = { bucket:BACKUP_BUCKET, key:"#{BACKUP_FOLDER}/#{BACKUP_FILENAME}.gz" }
      Aws::S3::Client.new(region: BACKUP_REGION).
        get_object(backup_location, target: "#{BACKUP_FILENAME}.gz")
      cmd.run(UNZIP_CMD, "#{BACKUP_FILENAME}.gz")
      abort("Unable to get the backup file.") unless File.exist?(BACKUP_FILENAME)
      cmd.run("heroku pg:psql --app", STAGING_APP_NAME, in: BACKUP_FILENAME)
      cmd.run("heroku run rake scihist:solr:reindex scihist:solr:delete_orphans --app ", STAGING_APP_NAME)
      cmd.run("aws s3 sync s3://scihist-digicoll-production-originals s3://scihist-digicoll-staging-originals")
      cmd.run("aws s3 sync s3://scihist-digicoll-production-derivatives s3://scihist-digicoll-staging-derivatives")
    ensure
      cmd.run("heroku maintenance:off --app", STAGING_APP_NAME)
      File.delete(BACKUP_FILENAME)         if File.exist?(BACKUP_FILENAME)
      File.delete("#{BACKUP_FILENAME}.gz") if File.exist?("#{BACKUP_FILENAME}.gz")
    end
  end
end