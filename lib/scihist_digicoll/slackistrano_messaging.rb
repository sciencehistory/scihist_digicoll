if defined?(Slackistrano::Messaging)
  module ScihistDigicoll
    class SlackistranoMessaging < Slackistrano::Messaging::Base
      def channels_for(action)
        channels = if fetch(:stage).to_s == "production"
          ["#digital-general"]
        else
          ["#digital-technical"]
        end
        if action == :failed
          channels << "#digital-technical"
        end
        channels.uniq
      end


      def username
        "Deploy Notification"
      end

      def payload_for_updated
        current = fetch(:current_revision)
        previous = fetch(:previous_revision)

        super.tap do |payload|
          if current && previous
            payload[:attachments] ||= []
            payload[:attachments] << {
                title: "Github Diff",
                title_link: "https://github.com/chemheritage/chf-sufia/compare/#{CGI.escape previous}...#{CGI.escape current}",
                short: false
              }
          end
        end
      end
    end
  end
end
