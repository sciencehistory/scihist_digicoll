namespace :scihist do
  desc "bundle exec rake scihist:sync_prod_to_staging" +

  " Downloads the latest database backup from s3;" +
  " replaces the staging database with it; updates SOLR;"
  " syncs originals and derivatives S3 buckets from prod to staging." +

  " ENV variables you can set: BACKUP_FOLDER; " +
  " BACKUP_BUCKET; BACKUP_FILENAME; STAGING_APP_NAME; and UNZIP_CMD."
  " Preface the command with USE_BACKUP=false if you don't want to bother using the backup."

  task :sync_prod_to_staging => :environment do
    BACKUP_BUCKET    = ENV['BACKUP_BUCKET']     || "chf-hydra-backup"
    BACKUP_FOLDER    = ENV['BACKUP_FOLDER']     || "PGSql"
    BACKUP_FILENAME  = ENV['BACKUP_FILENAME']   || "heroku-scihist-digicoll-backup"
    STAGING_APP_NAME = ENV['STAGING_APP_NAME']  || "scihist-digicoll-staging"
    UNZIP_CMD        = ENV['UNZIP_CMD']         || "gunzip --to-stdout"
    USE_BACKUP       = ENV['USE_BACKUP']        || "true"

    if ['staging', 'production'].include? ScihistDigicoll::Env.lookup(:service_level)
      abort 'This task should only be used in development.'
    end
    cmd = TTY::Command.new(printer: :progress)
    begin
      puts "Heroku maintenance on."
      cmd.run("heroku maintenance:on --app", STAGING_APP_NAME)
      if USE_BACKUP == 'true'
        puts "Downloading backup."
        cmd.run("aws s3 cp --no-progress s3://#{BACKUP_BUCKET}/#{BACKUP_FOLDER}/#{BACKUP_FILENAME}.sql.gz  #{BACKUP_FILENAME}.sql.gz")

        puts "Decompressing backup."
        cmd.run("#{UNZIP_CMD} #{BACKUP_FILENAME}.sql.gz > #{BACKUP_FILENAME}.sql")
        abort("Unable to get the backup file.") unless File.exist?("#{BACKUP_FILENAME}.sql")

        puts "Restoring backup to staging DB."
        Rails.logger.silence do
          cmd.run("heroku pg:psql --app", STAGING_APP_NAME, in: "#{BACKUP_FILENAME}.sql")
        end
      else
        puts "Copying backup from prod to staging."
        cmd.run("heroku pg:copy scihist-digicoll-production::DATABASE_URL DATABASE_URL -a #{STAGING_APP_NAME}  --confirm #{STAGING_APP_NAME}")
      end
      puts "Updating SOLR."
      cmd.run("heroku run rake scihist:solr:reindex scihist:solr:delete_orphans --app ", STAGING_APP_NAME)
      puts "Syncing originals."
      cmd.run("aws s3 sync --no-progress s3://scihist-digicoll-production-originals s3://scihist-digicoll-staging-originals")
      puts "Syncing derivatives."
      cmd.run("aws s3 sync --no-progress s3://scihist-digicoll-production-derivatives s3://scihist-digicoll-staging-derivatives")
    ensure
      puts "Heroku maintenance off."
      cmd.run("heroku maintenance:off --app", STAGING_APP_NAME)
      File.delete("#{BACKUP_FILENAME}.sql")            if File.exist?("#{BACKUP_FILENAME}.sql")
      File.delete("#{BACKUP_FILENAME}.sql.gz")         if File.exist?("#{BACKUP_FILENAME}.sql.gz")
      puts "Done."
    end
  end
end