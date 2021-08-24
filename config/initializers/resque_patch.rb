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
SanePatch.patch('resque', '2.1.0') do
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
