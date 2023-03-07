class ApplicationController < ActionController::Base
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
    redirect_path = if current_user.present?
      root_path
    else
      new_user_session_path
    end

    redirect_to redirect_path, alert: "You don't have permission to access requested page."
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
end
