# Patch in fix for Rails 7.1 RAM usage regression, until it is released presumably in
# Rails 7.1.3
#
# See https://github.com/rails/rails/pull/50298
#
# And where we discovered the RAM leak in our app, https://github.com/sciencehistory/scihist_digicoll/issues/2449

SanePatch.patch("rails", ">= 7.1.0", "< 7.1.3") do

  require "action_dispatch/routing/routes_proxy"

  module ActionDispatch
    module Routing
      class RoutesProxy

        private

        def method_missing(method, *args)
          if @helpers.respond_to?(method)
            options = args.extract_options!
            options = url_options.merge((options || {}).symbolize_keys)

            if @script_namer
              options[:script_name] = merge_script_names(
                options[:script_name],
                @script_namer.call(options)
              )
            end

            args << options
            @helpers.public_send(method, *args)
          else
            super
          end
        end
      end
    end
  end

end
