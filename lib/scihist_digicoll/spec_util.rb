module ScihistDigicoll
  module SpecUtil
    # Calls WebMock.disable_net_connect! with our desired exceptions.
    #
    # Exctracted into a utility method to make it easier to temporarily enable and then
    # disable to our standard settings again.
    #
    #    begin
    #       ScihistDigicoll::SpecUtil.allow_net_connect!
    #       # ...
    #    ensure
    #      ScihistDigicoll::SpecUtil.disable_net_connect!
    #    end
    def self.disable_net_connect!
      # localhost connections are allowed for Capybara (standard instructions) -- and also for our solr connections.
      # solr_wrapper sometimes wants to use 127.0.0.1 instead of localhost, so we need to explicitly mention
      # that too.

      # chromedriver.storage.googleapis.com for `webdrivers` gem automatic downloading of chromedriver.
      # https://github.com/titusfortner/webdrivers/issues/4

      # net_http_connect_on_start needed for reasons I don't totally understand
      # for "too many open files" error in capybara test that should be passing.
      # * https://stackoverflow.com/questions/59632283/chromedriver-capybara-too-many-open-files-socket2-for-127-0-0-1-port-951
      # * https://github.com/teamcapybara/capybara#gotchas
      # * https://github.com/bblimke/webmock/blob/master/README.md#connecting-on-nethttpstart

      WebMock.disable_net_connect!(allow_localhost: true, allow: ['127.0.0.1', 'chromedriver.storage.googleapis.com'], net_http_connect_on_start: true)
    end


    # Calls WebMock.disable_net_connect! with our desired exceptions.
    #
    # Extracted into utility so we can make sure we do it consistently.
    def self.allow_net_connect!
      # net_http_connect_on_start needed for reasons I don't totally understand
      # for "too many open files" error in capybara test that should be passing.
      # * https://stackoverflow.com/questions/59632283/chromedriver-capybara-too-many-open-files-socket2-for-127-0-0-1-port-951
      # * https://github.com/teamcapybara/capybara#gotchas
      # * https://github.com/bblimke/webmock/blob/master/README.md#connecting-on-nethttpstart
      WebMock.allow_net_connect!(net_http_connect_on_start: true)
    end

  end
end
