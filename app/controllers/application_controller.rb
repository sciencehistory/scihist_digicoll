class ApplicationController < ActionController::Base
  # This will only protect CONFIGURED routes, but also could be put on just certain
  # controllers, it does not need to be in ApplicationController
  before_action do |controller|
    BotChallengePage::BotChallengePageController.bot_challenge_enforce_filter(controller)
  end

  # Store bot challenged requests to database, because we won't be logging them
  after_action do |controller|
    if controller.request.env["bot_detect.blocked_for_challenge"]
      BotChallengedRequest.save_from_request(controller.request)
    end
  end

  # Blacklight tried to add some things to ApplicationController, but
  # we pretty much only want to use CatalogController from Blacklight, so
  # are trying just doing these things there instead
  #
  # See: https://github.com/projectblacklight/blacklight/issues/2095
  #
  #      # Adds a few additional behaviors into the application controller
  #      include Blacklight::Controller
  #      layout :determine_layout if respond_to? :layout


  # intended for use on staging, set ENV variables on (eg) heroku config
  # to put an HTTP Basic Auth form in front of entire site.
  if ENV['HTTP_BASIC_AUTH_NAME'].present? && ENV['HTTP_BASIC_AUTH_PASSWORD'].present?
    http_basic_authenticate_with name: ENV['HTTP_BASIC_AUTH_NAME'], password: ENV['HTTP_BASIC_AUTH_PASSWORD']
  end


  rescue_from "AccessGranted::AccessDenied" do |exception|
    redirect_to root_path, alert: "You don't have permission to access that page."
  end

  around_action :batch_kithe_indexable

  def batch_kithe_indexable
    Kithe::Indexable.index_with(batching: true) do
      yield
    end
  end

  before_action do
    timecode = Time.now.gmtime.to_i
    Honeybadger.context({
      :papertrail_url => "https://papertrailapp.com/events?focus=#{timecode}&selected=#{timecode}",
      :request_id => request.uuid,
      :current_user_email => current_user&.email
    })
  end


  def show_ie_unsupported_warning?
    # #browser method comes from `browser` gem
    browser.ie? && !cookies[:ieWarnDismiss]
  end
  helper_method :show_ie_unsupported_warning?

  # Since we're displaying the log in link on every page,
  # after the user logs in successfully, let's redirect to
  # wherever they were before they clicked the log in link.
  # See https://www.rubydoc.info/github/plataformatec/devise/Devise/Controllers/Helpers
  def after_sign_in_path_for(resource)
    stored_location_for(resource) || request.env['omniauth.origin'] || super
  end

end
