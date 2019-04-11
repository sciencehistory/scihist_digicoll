class ApplicationController < ActionController::Base
  rescue_from "AccessGranted::AccessDenied" do |exception|
    redirect_to root_path, alert: "You don't have permission to access requested page."
  end

  around_action :batch_kithe_indexable

  def batch_kithe_indexable
    Kithe::Indexable.index_with(batching: true) do
      yield
    end
  end

end
