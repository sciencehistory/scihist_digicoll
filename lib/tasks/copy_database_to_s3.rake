require 'tty/command'
require 'tempfile'

namespace :scihist do
  desc """
    Dump the live database and upload it to s3.

    BACKUP_AWS_ACCESS_KEY_ID=joe \
    BACKUP_AWS_SECRET_ACCESS_KEY=schmo \
    APP=scihist-digicoll-2 \
    rake scihist:copy_database_to_s3

    The s3 destination parameters can also be overridden via ENV variables.:
      REGION=us-west-2
      BUCKET=chf-hydra-backup
      FILE_PATH=PGSql/digcol_backup_2.sql

  """
  task :copy_database_to_s3 => :environment do
    region = ENV['REGION'] || 'us-west-2'
    bucket = ENV['BUCKET']  || 'chf-hydra-backup'
    file_path = ENV['FILE_PATH'] || 'PGSql/digcol_backup_2.sql'
    abort 'Please supply BACKUP_AWS_ACCESS_KEY_ID' unless ENV['BACKUP_AWS_ACCESS_KEY_ID'].is_a? String
    abort 'Please supply BACKUP_AWS_SECRET_ACCESS_KEY.' unless ENV['BACKUP_AWS_SECRET_ACCESS_KEY'].is_a? String
    aws_client = Aws::S3::Client.new(
      region:            region,
      access_key_id:     ENV['BACKUP_AWS_ACCESS_KEY_ID'],
      secret_access_key: ENV['BACKUP_AWS_SECRET_ACCESS_KEY']
    )
    cmd = TTY::Command.new(printer: :null)
    puts "Uploading database to s3."
    aws_bucket = Aws::S3::Bucket.new(name: bucket, client: aws_client)
    aws_object = aws_bucket.object(file_path)
      result = aws_object.upload_stream(
        content_type: "application/sql; charset=utf-8",
        storage_class: "STANDARD_IA",
        metadata: { "backup_time" => Time.now.utc.to_s}
      ) do |write_stream|
      cmd.run('pg_dump', '-w', '--clean', ENV['DATABASE_URL']) do |out, err|
        write_stream << out.force_encoding('UTF-8') if out
      end
    end
    raise RuntimeError.new "Upload failed." unless result
  end
end
