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
    # ---- TEMPORARY MEMORY INSTRUMENTATION (remove after diagnosing R14) ----
    # Logs the Ruby process RSS and the whole-dyno total RSS (which includes the
    # pg_dump/gzip child processes), plus the cgroup memory figure -- the last is
    # what Heroku's R14 actually measures. A background thread samples every 2s so
    # we also catch the peak *during* the blocking S3 upload. Degrades to zeros
    # off-Linux (e.g. local dev), so it's safe to run anywhere.
    phase = "startup"
    read_field = ->(text, field) { (text[/^#{field}:\s+(\d+)/, 1] || 0).to_i }
    dyno_total_rss_kb = lambda do
      Dir.glob("/proc/[0-9]*/status").sum do |f|
        begin; read_field.(File.read(f), "VmRSS"); rescue StandardError; 0; end
      end
    end
    cgroup_mem_mb = lambda do
      raw = begin
        File.read("/sys/fs/cgroup/memory.current")                            # cgroup v2
      rescue StandardError
        File.read("/sys/fs/cgroup/memory/memory.usage_in_bytes") rescue nil   # cgroup v1
      end
      raw ? (raw.to_i / 1_048_576.0).round : nil
    end
    mem_report = lambda do |label|
      status = File.read("/proc/self/status") rescue ""
      msg = "[MEM] #{label} | ruby_rss=#{(read_field.(status, 'VmRSS') / 1024.0).round}MB " \
            "ruby_peak=#{(read_field.(status, 'VmHWM') / 1024.0).round}MB " \
            "dyno_total=#{(dyno_total_rss_kb.call / 1024.0).round}MB " \
            "cgroup=#{cgroup_mem_mb.call || 'n/a'}MB"
      $stdout.puts(msg); $stdout.flush
      Rails.logger.info(msg)
    end
    mem_sampler = Thread.new do
      loop { mem_report.call("sample/#{phase}"); sleep 2 }
    end
    mem_report.call("startup")
    # ------------------------------------------------------------------------

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

    phase = "pg_dump"; mem_report.call("before pg_dump")
    cmd.run!(dump_command, :out => temp_file_1.path )
    mem_report.call("after pg_dump (uncompressed=#{(temp_file_1.size / 1_048_576.0).round}MB)")

    # zip file 1 into file 2
    phase = "gzip"; mem_report.call("before gzip")
    cmd.run!('gzip', '-c', temp_file_1.path, :out => temp_file_2.path )
    mem_report.call("after gzip (gzipped=#{(temp_file_2.size / 1_048_576.0).round}MB)")

    aws_bucket = Aws::S3::Bucket.new(name: bucket, client: aws_client)
    aws_object = aws_bucket.object(s3_backup_file_path)

    raise "Backup file looks too small. (#{temp_file_2.size} bytes)." unless temp_file_2.size > 100000000

    phase = "s3_upload"; mem_report.call("before s3 upload")
    result = aws_object.upload_file(temp_file_2.path,
        # AWS allocates LOTS of strings and has a big RAM ceiling when uploading
        # a bit file. Reducing thread count from default 10 is a way to try
        # to stay under heroku standard-1x limit.
        thread_count: 4,
        content_type: "application/gzip",
        storage_class: "STANDARD_IA",
        metadata: { "backup_time" => Time.now.utc.to_s, "git_sha_hash" => ENV['SOURCE_VERSION'] }
        )
    mem_report.call("after s3 upload")

    raise "Upload failed" unless result

    temp_file_1.unlink
    temp_file_2.unlink

    mem_sampler.kill
    mem_report.call("done")
  end
end
