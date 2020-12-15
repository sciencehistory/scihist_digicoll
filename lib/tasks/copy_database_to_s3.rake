require 'tty/command'
require 'down'

namespace :scihist do
  desc """
    Copy the latest copy of the database to a location on s3.

    AWS_ACCESS_KEY_ID=joe AWS_SECRET_ACCESS_KEY=schmo bundle exec rake scihist:copy_database_to_s3
    Note: this is a Postgres binary .dump file, not ASCII SQL. You can convert it to regular sql like this: pg_restore -f mydatabase.sql latest.dump
  """

  task :copy_database_to_s3 => :environment do
    puts "Starting :copy_database_to_s3"
    cmd = TTY::Command.new(output: Rails.logger)
    get_database_url_args = ['heroku', 'pg:backups:url', '--app', 'scihist-digicoll-2']

    puts "Attempting to get the database URL."
    result =  cmd.run!(*get_database_url_args, only_output_on_error: true)
    if result.failure?
      raise RuntimeError, "Unable to obtain the URL of the latest database backup."
    end
    puts "Successfully got the database URL: #{result.out}. Now uploading it."
    aws_client = Aws::S3::Client.new(region: 'us-west-2')
    aws_bucket = Aws::S3::Bucket.new(name: 'chf-hydra-backup', client: aws_client)
    aws_object = aws_bucket.object('PGSql/digcol_backup.dump')
    result = aws_object.put(body: Down.open(result.out), storage_class: "STANDARD_IA")
    puts "Result from PUT to S3: #{result}."
    puts "Completing :copy_database_to_s3"
  end
end
