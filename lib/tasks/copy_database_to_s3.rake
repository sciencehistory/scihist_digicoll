require 'tty/command'
require 'tempfile'

namespace :scihist do
  desc """
    Dump the live database and upload it to s3.

    S3_BACKUP_ACCESS_KEY_ID=joe \
    S3_BACKUP_SECRET_ACCESS_KEY=schmo \
    APP=scihist-digicoll \
    rake scihist:copy_database_to_s3

    The s3 destination parameters can also be overridden via ENV variables.:
      REGION=us-west-2
      BUCKET=chf-hydra-backup
      FILE_PATH=PGSql/digcol_backup.sql.gz
  """
  task :copy_database_to_s3 => :environment do
    region = ScihistDigicoll::Env.lookup(:s3_backup_bucket_region)
    bucket = ENV['BUCKET']  || 'chf-hydra-backup'
    file_path = ENV['FILE_PATH'] || 'PGSql/digcol_backup.sql.gz'

    # Don't overwrite the prod backup with a staging backup.
    # abort 'This task should only be used in production' unless ScihistDigicoll::Env.lookup(:service_level) == 'production'
    aws_client = Aws::S3::Client.new(
      region:            ScihistDigicoll::Env.lookup!(:s3_backup_bucket_region),
      access_key_id:     ScihistDigicoll::Env.lookup!(:s3_backup_access_key_id),
      secret_access_key: ScihistDigicoll::Env.lookup!(:s3_backup_secret_access_key)
    )
    cmd = TTY::Command.new(printer: :null)
    temp_file_1 = Tempfile.new(['temp_database_dump','.sql'])
    temp_file_2 = Tempfile.new(['temp_database_dump','.gz'])

    cmd.run!('pg_dump', '-w', '--no-owner', '--no-acl', '--clean', ENV['DATABASE_URL'], :out => temp_file_1.path )
    cmd.run!('gzip', '-c', temp_file_1.path, :out => temp_file_2.path )

    aws_bucket = Aws::S3::Bucket.new(name: bucket, client: aws_client)
    aws_object = aws_bucket.object(file_path)
    aws_object.upload_file(temp_file_2.path,
        content_type: "application/gzip",
        storage_class: "STANDARD_IA",
        metadata: { "backup_time" => Time.now.utc.to_s}
        )
    temp_file_1.unlink
    temp_file_2.unlink
  end
end
