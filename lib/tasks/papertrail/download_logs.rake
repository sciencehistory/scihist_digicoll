# Our Papertrail Heroku add-on account was migrated to SolarWinds Observability,
# which serves log archives from a different API than classic Papertrail:
# https://documentation.solarwinds.com/en/success_center/observability/content/intro/logs/migrate-papertrail-guide.htm
#
# SolarWinds Observability public API docs:
# https://documentation.solarwinds.com/en/success_center/observability/content/api/api.htm
# Interactive API reference (includes the /v1/logs/archives endpoint we use below):
# https://api.na-01.cloud.solarwinds.com/v1/#/

require "http"
require "zlib"
require "stringio"
require "json"

module PapertrailArchiveDownloadHelper
  # Yields once, retrying one more time if it raises HTTP::Error; re-raises if the retry also fails.
  def self.http_with_one_retry
    attempts ||= 0
    yield
  rescue HTTP::Error
    attempts += 1
    attempts <= 1 ? retry : raise
  end
end

namespace :scihist do
  namespace :papertrail do
    desc <<~DESC
      Download SolarWinds Observability (for Papertrail) per-hour log archives for a
      given day, or range of days.

        [DIR=./some-logs] SOLARWINDS_API_TOKEN=abc123 ./bin/rake scihist:papertrail:download_logs[2026-09-10]

      Or for a date range from start to end inclusive.

        [DIR=./some-logs] SOLARWINDS_API_TOKEN=abc123 ./bin/rake scihist:papertrail:download_logs[2026-09-10,2026-09-12]

      Token must be an "API Access token" from Settings > API Tokens in the
      SolarWinds Observability (Papertrail) console (for production app if you want
      production logs!)

      Default DIR is ./tmp/papertrail-logs

      Files are written as <date>-<hour>.json into the current directory, or DIR
      if given, ungzipped by default. Set LEAVE_GZIP=1 to keep them gzipped
      (<date>-<hour>.json.gz) instead.
    DESC
    task :download_logs, [:start_date, :end_date] => :environment do |_t, args|
      start_date = args[:start_date] or abort "require date(s), usage: rake scihist:papertrail:download_logs[2026-09-10] or scihist:papertrail:download_logs[2026-09-10,2026-09-12]"
      end_date = args[:end_date] || start_date

      token = ENV["SOLARWINDS_API_TOKEN"].presence or abort "set SOLARWINDS_API_TOKEN env var, an API Access token from Papertrail Settings > API Tokens"

      abort "#{start_date} is more than a year ago -- SolarWinds Observability only keeps log archives for a year" if Date.parse(start_date) < Date.today - 365

      dir = ENV["DIR"] || "./tmp/papertrail-logs"
      FileUtils.mkdir_p(dir)

      client = HTTP.headers("Authorization" => "Bearer #{token}")
      archives_url = "https://api.na-01.cloud.solarwinds.com/v1/logs/archives"

      start_time = Date.parse(start_date).strftime("%Y-%m-%dT00:00:00Z")
      end_time = Date.parse(end_date).strftime("%Y-%m-%dT23:59:59Z")

      # initial fetch url, will give first page of results, will follow
      # pagination metadata in returned reposnse to set next_url to next
      # page until all done.
      next_url = "#{archives_url}?#{URI.encode_www_form(startTime: start_time, endTime: end_time, pageSize: 100)}"
      found_any = false

      loop do
        begin
          response = PapertrailArchiveDownloadHelper.http_with_one_retry { client.get(next_url) }
        rescue HTTP::Error => e
          abort "giving up listing archives: #{e.message}"
        end

        abort "HTTP #{response.status} listing archives: #{response.to_s[0, 300]}" unless response.status.success?

        page = JSON.parse(response.to_s)

        page["logArchives"].each do |archive|
          found_any = true
          name = archive.fetch("name") # e.g. "2026-09-10-08.json.gz"

          begin
            file_response = PapertrailArchiveDownloadHelper.http_with_one_retry { HTTP.follow.get(archive.fetch("downloadUrl")) }
          rescue HTTP::Error => e
            warn "#{name}: #{e.message}, skipping"
            next
          end

          unless file_response.status.success?
            warn "#{name}: HTTP #{file_response.status}, skipping"
            next
          end

          gz_body = file_response.to_s

          if ENV["LEAVE_GZIP"]
            File.binwrite(File.join(dir, name), gz_body)
            puts "wrote #{File.join(dir, name)}"
          else
            path = File.join(dir, name.sub(/\.gz\z/, ""))
            File.write(path, Zlib::GzipReader.new(StringIO.new(gz_body)).read)
            puts "wrote #{path}"
          end
        end

        next_url = page.dig("pageInfo", "nextPage").presence
        break unless next_url
      end

      warn "no log archives found for #{start_date}..#{end_date}" unless found_any
    end
  end
end
