# Monkey-patching an apparent bug in resque.
#
# Bug exhibited on heroku as OpenSSL::SSL::SSLError: SSL_read: sslv3 alert bad record mac
#
# This stackoverflow: https://stackoverflow.com/questions/50228454/why-am-i-getting-opensslsslsslerror-ssl-read-sslv3-alert-bad-record-mac
#
# Led us to this unmerged resque PR: https://github.com/resque/resque/pull/1739
#
# Which we are trying as a monkey-patch, redefining the Resque::DataStore#reconnect method.
#
# We'll refuse to run and require manual review if resque is more than 2.0.0 -- maybe
# resque will have fixed this itself, or changed in a way that makes the monkey-patch not work.
SanePatch.patch('resque', '2.0.0') do
  Resque::DataStore

  module Resque
    class DataStore
      # Force a reconnect to Redis without closing the connection in the parent
      # process after a fork.
      def reconnect
        @redis._client.connect
      end
    end
  end
end


# TEMPORARY EXPERIMENTAL hackily override resque logging so it can log what we're interseted
# in about graceful restart in the signal trap handling.
module HackyDirectResqueWorkerLogging
  # We're just going to log directly to stdout -- with no mutex, so under multi-threaded
  # use log messages could step on each other. And without bothering to respect log_level.
  #
  # This is just a hacky debugging-for-now technique!
  def log_with_severity(severity, message)
    $stdout.puts "resque: #{severity}: #{message}"
  end
end
Resque::Worker.prepend(HackyDirectResqueWorkerLogging)
