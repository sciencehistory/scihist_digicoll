module Scihist
  # Custom sub-class of stock blacklight, to override build_connection
  # to provide custom faraday middleware for HTTP retries
  #
  # This may not be a totally safe forwards-compat Blacklight API
  # thing to do, but the only/best way we could find to add-in
  # Solr retries.
  class BlacklightSolrRepository < Blacklight::Solr::Repository
    # this is really only here for use in testing, skip the wait in tests
    class_attribute :zero_interval_retry, default: false

    # call super, but then mutate the faraday_connection on
    # the returned RSolr 2.x+ client, to customize the middleware
    # and add retry.
    def build_connection(*_args, **_kwargs)
      super.tap do |rsolr_client|
        faraday_connection = rsolr_client.connection

        # remove if already present, so we can add our own
        faraday_connection.builder.delete(Faraday::Retry::Middleware)

        # remove so we can make sure it's there AND added AFTER our
        # retry, so our retry can succesfully catch it's exceptions
        faraday_connection.builder.delete(Faraday::Response::RaiseError)

        # add retry middleware with our own confiuration
        # https://github.com/lostisland/faraday/blob/main/docs/middleware/request/retry.md
        #
        # Retry at most twice, once after 300ms, then if needed after
        # another 600 ms (backoff_factor set to result in that)
        # Slow, but the idea is slow is better than an error, and our
        # app is already kinda slow.
        #
        # Retry not only the default Faraday exception classes (including timeouts),
        # but also Solr returning a 404 or 502. Which gets converted to
        # Faraday error because RSolr includes raise_error middleware already.
        #
        # Log retries. I wonder if there's a way to have us alerted if
        # there are more than X in some time window Y...
        faraday_connection.request :retry, {
          interval: (zero_interval_retry ? 0 : 0.300),
          # exponential backoff 2 means: 1) 0.300; 2) .600; 3) 1.2; 4) 2.4
          backoff_factor: 2,
          # But we only actually only ONE retry at present, so it should be 300ms
          max: 1,
          exceptions: [
            # default faraday retry exceptions
            Errno::ETIMEDOUT,
            Timeout::Error,
            Faraday::TimeoutError,
            Faraday::RetriableResponse, # important to include when overriding!
            # we add some that could be Solr/jetty restarts, based
            # on our observations:
            Faraday::ConnectionFailed,  # nothing listening there at all,
            Faraday::ResourceNotFound, # HTTP 404
            Faraday::ServerError # any HTTP 5xx
          ],

          retry_block: -> (env:, options:, retry_count:, exception:, will_retry_in:) do
            Rails.logger.warn(<<-EOS.strip_heredoc
              #{self.class}: Retrying Solr request: HTTP #{env&.status}: #{exception&.class}: retry #{retry_count + 1}: will try again in #{will_retry_in}s\n\n\
                url: #{env&.url&.to_s}
                response: #{env&.response&.body&.slice(0, 150)}
              EOS
            )
          end
        }

        # important to add this AFTER retry, to make sure retry can
        # rescue and retry it's errors
        faraday_connection.response :raise_error
      end
    end
  end
end
