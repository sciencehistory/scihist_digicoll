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
    temp_file_2 = Tempfile.new(['temp_database_dump_with_git_hash','.sql'])
    temp_file_3 = Tempfile.new(['temp_database_dump','.sql.gz'])


    cmd.run!('pg_dump', '--no-password', '--no-owner', '--no-acl', '--clean', ENV['DATABASE_URL'], :out => temp_file_1.path )


    # Obtain, by questionble means, the GIT sha hash for the master branch:
    #
    # Note:
    # git ls-remote https://github.com/sciencehistory/scihist_digicoll.git master
    # would have been better, but we don't have git installed on heroku dynos by default.
    #
    git_sha_line = cmd.run("curl -s https://api.github.com/repos/sciencehistory/scihist_digicoll/branches/master | grep 'sha'  | head -1").out
    git_sha = git_sha_line.scan(/\"(.*?)\"/)[1][0]


    # Put the sha and the backup into file_2
    cmd.run "echo \"-- GIT SHA:\"                    >  #{temp_file_2.path}"
    cmd.run "echo \"-- #{git_sha}\n\"                >> #{temp_file_2.path}"
    cmd.run "cat  \"#{temp_file_1.path}\"            >> #{temp_file_2.path}"

    # This gives us:
    # -- GIT SHA:
    # -- afd2bd0b69f585bfb977649af946cc40abf051ea

    # --
    # -- PostgreSQL database dump
    # --
    #
    # [...]


    # Zip file 2 into file 3
    cmd.run!('gzip', '-c', temp_file_2.path, :out => temp_file_3.path )

    aws_bucket = Aws::S3::Bucket.new(name: bucket, client: aws_client)
    aws_object = aws_bucket.object(s3_backup_file_path)

    raise "Backup file looks too small. (#{temp_file_3.size} bytes)." unless temp_file_3.size > 100000000

    result = aws_object.upload_file(temp_file_3.path,
        content_type: "application/gzip",
        storage_class: "STANDARD_IA",
        metadata: { "backup_time" => Time.now.utc.to_s, "git_sha_hash" => git_sha }
        )

    raise "Upload failed" unless result

    temp_file_1.unlink
    temp_file_2.unlink
    temp_file_3.unlink
  end
end
