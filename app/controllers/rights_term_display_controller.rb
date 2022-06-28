class RightsTermDisplayController < ApplicationController

  def show
    @rights_term = RightsTerm.find_by_param_id(params[:id])
    @work = Work.find_by_friendlier_id(params[:work_id]) if params[:work_id].present?

    unless @rights_term
      raise ActionController::RoutingError.new("No RightsTerm param_id found for `#{params[:id]}`")
    end
  end

end
