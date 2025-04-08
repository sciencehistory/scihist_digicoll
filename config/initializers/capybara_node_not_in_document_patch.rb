# Trying to fix
# https://github.com/teamcapybara/capybara/issues/2800

if (Rails.env.test? || (defined?(Capybara::Node::Base) && defined?(Selenium::WebDriver::Error::UnknownError)))
  SanePatch.patch('capybara', '< 3.41', details: "Check and see if patch is still needed at this capybara version for https://github.com/teamcapybara/capybara/issues/2800") do
    unless Capybara::Node::Base.instance_methods.include?(:catch_error?)
      raise "Could not patch Capybara::Node::Base#catch_error? becuase it did not exist! Trying to patch for https://github.com/teamcapybara/capybara/issues/2800"
    end

    Capybara::Node::Base.prepend(Module.new do
      protected

      # https://github.com/teamcapybara/capybara/blob/0480f90168a40780d1398c75031a255c1819dce8/lib/capybara/node/base.rb#L134C10-L137
      #
      # and see
      #
      # https://github.com/teamcapybara/capybara/blob/0480f90168a40780d1398c75031a255c1819dce8/lib/capybara/node/base.rb#L85-L99
      def catch_error?(error, *args)
        super || (error.kind_of?(Selenium::WebDriver::Error::UnknownError) && error.message.include?("Node with given id does not belong to the document"))
      end
    end)
  end
end

