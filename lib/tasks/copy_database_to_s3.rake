require 'tty/command'
require 'down'

namespace :scihist do
  desc """
    Copy the latest copy of the database to a location on s3.

    BACKUP_AWS_ACCESS_KEY_ID=joe \
    BACKUP_AWS_SECRET_ACCESS_KEY=schmo \
    APP=scihist-digicoll-2 \
    rake scihist:copy_database_to_s3

    These params can be overridden:
      REGION=us-west-2
      BUCKET=chf-hydra-backup
      FILE_PATH=PGSql/digcol_backup.dump

    Note: this is a Postgres binary .dump file, not ASCII SQL. You can convert it to regular sql like this: pg_restore -f mydatabase.sql latest.dump

    Setup:
      1) Install the Heroku CLI buildpack, then redeploy the app
        heroku buildpacks:add heroku-community/cli
      2) To give us access to the Heroku CLI, run:
        heroku config:set HEROKU_API_KEY=`heroku auth:token`
  """

  # wget -O - -o /dev/null  `heroku pg:backups:url` | pg_restore -f mydatabase.sql

  task :copy_database_to_s3 => :environment do
    region = ENV['REGION'] || 'us-west-2'
    bucket = ENV['BUCKET']  || 'chf-hydra-backup'
    file_path = ENV['FILE_PATH'] || 'PGSql/digcol_backup.dump'
    cmd = TTY::Command.new(output: Rails.logger)
    abort 'Please supply BACKUP_AWS_ACCESS_KEY_ID' unless ENV['BACKUP_AWS_ACCESS_KEY_ID'].is_a? String
    abort 'Please supply BACKUP_AWS_SECRET_ACCESS_KEY.' unless ENV['BACKUP_AWS_SECRET_ACCESS_KEY'].is_a? String

    aws_client = Aws::S3::Client.new(
       region:            region,
       access_key_id:     ENV['BACKUP_AWS_ACCESS_KEY_ID'],
       secret_access_key: ENV['BACKUP_AWS_SECRET_ACCESS_KEY']
     )
    aws_bucket = Aws::S3::Bucket.new(name: bucket, client: aws_client)
    aws_object = aws_bucket.object(file_path)
    result = aws_object.put(body: cmd.run!('pg_dump', '-w', '--clean', "$DATABASE_URL").out, storage_class: "STANDARD_IA")
  end

end
