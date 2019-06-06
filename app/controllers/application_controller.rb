class ApplicationController < ActionController::Base
  # Blacklight tried to add some things to ApplicationController, but
  # we pretty much only want to use CatalogController from Blacklight, so
  # are trying just doing these things there instead
  #
  #      # Adds a few additional behaviors into the application controller
  #      include Blacklight::Controller
  #      layout :determine_layout if respond_to? :layout

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

end
