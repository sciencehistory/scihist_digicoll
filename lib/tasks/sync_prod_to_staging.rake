namespace :scihist do
  desc "bundle exec rake scihist:sync_prod_to_staging" +

  " Downloads the latest database backup from s3;" +
  " replaces the staging database with it; updates SOLR;"
  " syncs originals and derivatives S3 buckets from prod to staging." +

  " ENV variables you can set: BACKUP_FOLDER; " +
  " BACKUP_BUCKET; BACKUP_FILENAME; STAGING_APP_NAME; and UNZIP_CMD"

  task :sync_prod_to_staging => :environment do
    BACKUP_BUCKET    = ENV['BACKUP_BUCKET']     || "chf-hydra-backup"
    BACKUP_FOLDER    = ENV['BACKUP_FOLDER']     || "PGSql"
    BACKUP_FILENAME  = ENV['BACKUP_FILENAME']   || "heroku-scihist-digicoll-backup.sql"
    STAGING_APP_NAME = ENV['STAGING_APP_NAME']  || "scihist-digicoll-staging"
    UNZIP_CMD        = ENV['UNZIP_CMD']         || "gunzip --force"
    if ['staging', 'production'].include? ScihistDigicoll::Env.lookup(:service_level)
      abort 'This task should only be used in development.'
    end
    cmd = TTY::Command.new
    begin
      cmd.run("heroku maintenance:on --app", STAGING_APP_NAME)
      cmd.run("aws s3 cp s3://#{BACKUP_BUCKET}/#{BACKUP_FOLDER}/#{BACKUP_FILENAME}.gz  #{BACKUP_FILENAME}.gz")
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