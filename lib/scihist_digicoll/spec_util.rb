module ScihistDigicoll
  module SpecUtil
    # Calls WebMock.disable_net_connect! with our desired exceptions.
    #
    # Exctracted into a utility method to make it easier to temporarily enable and then
    # disable to our standard settings again.
    #
    #    begin
    #       WebMock.allow_net_connect!
    #       # ...
    #    ensure
    #      ScihistDigicoll::SpecUtil.disable_net_connect!
    #    end
    def self.disable_net_connect!
      # chromedriver.storage.googleapis.com for `webdrivers` gem automatic downloading of chromedriver.
      # https://github.com/titusfortner/webdrivers/issues/4
      #
      # solr_wrapper wants to use 127.0.0.1 instead of localhost.
      WebMock.disable_net_connect!(allow_localhost: true, allow: ['127.0.0.1', 'chromedriver.storage.googleapis.com'])
    end
  end
end
