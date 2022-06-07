class RightsTermDisplayController < ApplicationController

  def show
    @rights_term = RightsTerm.find_by_param_id(params[:id])

    unless @rights_term
      raise ActionController::RoutingError.new("No RightsTerm param_id found for `#{params[:id]}`")
    end
  end

end
