require 'tty/command'
require 'tempfile'

namespace :scihist do
  desc """
    Dump the live database and upload it to s3.

    Assumes the presence of db_dump, and of a working database URL (complete with credentials) at ENV['DATABASE_URL'].
    We use it to back up our database from Heroku to s3, in a dyno spun up nightly by the Heroku Scheduler addon.

    bundle exec rake scihist:copy_database_to_s3
    heroku run rake scihist:copy_database_to_s3 # although see caveat re: heroku run rake below.

    The s3 destination can also be temporarily
    overridden in the command line, for testing.
      BUCKET=chf-hydra-backup
      S3_BACKUP_FILE_PATH=PGSql/heroku-scihist-digicoll-backup.sql.gz

  """
  task :copy_database_to_s3 => :environment do
    region = ScihistDigicoll::Env.lookup(:s3_backup_bucket_region)
    bucket   = ENV['BUCKET']                         || 'chf-hydra-backup'
    s3_backup_file_path = ScihistDigicoll::Env.lookup!(:s3_backup_file_path)


    # Don't overwrite the prod backup with a staging backup.
    abort 'This task should only be used in production' unless ScihistDigicoll::Env.lookup(:service_level) == 'production'

    aws_client = Aws::S3::Client.new(
      region:            ScihistDigicoll::Env.lookup!(:s3_backup_bucket_region),
      access_key_id:     ScihistDigicoll::Env.lookup!(:s3_backup_access_key_id),
      secret_access_key: ScihistDigicoll::Env.lookup!(:s3_backup_secret_access_key)
    )
    cmd = TTY::Command.new(printer: :null)
    temp_file_1 = Tempfile.new(['temp_database_dump','.sql'])
    temp_file_2 = Tempfile.new(['temp_database_dump','.sql.gz'])


    unless ENV['SOURCE_VERSION'].present?
      raise "Unable to obtain source version."
    end

    dump_command = [
      'echo', "\"-- GIT SHA:\"",                 '&&',
      'echo', "\"-- #{ENV['SOURCE_VERSION']}\"", '&&',

      # --clean means "include DROP commands at the top of the file."
      'pg_dump', '--no-password', '--no-owner', '--no-acl', '--clean', ENV['DATABASE_URL']
    ].join(" ")

    cmd.run!(dump_command, :out => temp_file_1.path )

    # zip file 1 into file 2
    cmd.run!('gzip', '-c', temp_file_1.path, :out => temp_file_2.path )

    aws_bucket = Aws::S3::Bucket.new(name: bucket, client: aws_client)
    aws_object = aws_bucket.object(s3_backup_file_path)

    raise "Backup file looks too small. (#{temp_file_2.size} bytes)." unless temp_file_2.size > 100000000

    result = aws_object.upload_file(temp_file_2.path,
        content_type: "application/gzip",
        storage_class: "STANDARD_IA",
        metadata: { "backup_time" => Time.now.utc.to_s, "git_sha_hash" => git_sha }
        )

    raise "Upload failed" unless result

    temp_file_1.unlink
    temp_file_2.unlink
  end
end
