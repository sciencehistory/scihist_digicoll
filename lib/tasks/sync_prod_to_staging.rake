namespace :scihist do
  desc "bundle exec rake scihist:sync_prod_to_staging" +

  " Downloads the latest database backup from s3;" +
  " replaces the staging database with it; updates SOLR;"
  " syncs originals and derivatives S3 buckets from prod to staging." +

  " ENV variables you can set: BACKUP_FOLDER; " +
  " BACKUP_BUCKET; BACKUP_FILENAME; STAGING_APP_NAME; and UNZIP_CMD." +
  " Preface the command with USE_BACKUP=false to use direct heroku copy (faster) " +
  "    instead of restoring from our off-heroku backup (tests backup)."

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
    cmd = TTY::Command.new(printer: :pretty)
    begin
      puts "\nHeroku maintenance on."
      cmd.run("heroku maintenance:on --app", STAGING_APP_NAME)
      if USE_BACKUP == 'true'
        Dir.mktmpdir do |tmpdir|
          puts "\nDownloading backup."
          cmd.run("aws s3 cp --no-progress s3://#{BACKUP_BUCKET}/#{BACKUP_FOLDER}/#{BACKUP_FILENAME}.sql.gz  #{tmpdir}/#{BACKUP_FILENAME}.sql.gz")

          puts "\nDecompressing backup."
          cmd.run("#{UNZIP_CMD} #{tmpdir}/#{BACKUP_FILENAME}.sql.gz > #{tmpdir}/#{BACKUP_FILENAME}.sql")
          abort("Unable to get unzipped backup file!") unless File.exist?("#{tmpdir}/#{BACKUP_FILENAME}.sql")

          puts "\nRestoring backup to staging DB."

          # This pg:psql load has a LOT of output, we suppress it. We could send to
          # a log file or something instead if we wanted it.
          cmd.run("heroku pg:psql --app", STAGING_APP_NAME, in: "#{tmpdir}/#{BACKUP_FILENAME}.sql", out: "/dev/null", err: "/dev/null")
        end
      else
        puts "\nCopying backup from prod to staging."
        cmd.run("heroku pg:copy scihist-digicoll-production::DATABASE_URL DATABASE_URL -a #{STAGING_APP_NAME}  --confirm #{STAGING_APP_NAME}")
      end

      puts "\nUpdating Solr index."
      # heroku --no-tty makes ruby-progressbar somewhat less spammy to our console,although not perfect, tolerable.
      cmd.run("heroku run rake scihist:solr:reindex scihist:solr:delete_orphans --app ", STAGING_APP_NAME, "--no-tty")

      puts "\nSyncing S3 originals (with --delete)."
      cmd.run("aws s3 sync --only-show-errors --delete s3://scihist-digicoll-production-originals s3://scihist-digicoll-staging-originals")

      puts "\nSyncing S3 derivatives (with --delete)."
      cmd.run("aws s3 sync --only-show-errors --delete s3://scihist-digicoll-production-derivatives s3://scihist-digicoll-staging-derivatives")
    ensure
      puts "\nHeroku maintenance off."
      cmd.run("heroku maintenance:off --app", STAGING_APP_NAME)
      puts "\nDone."
    end
  end
end
