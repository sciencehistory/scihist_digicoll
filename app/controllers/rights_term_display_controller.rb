class RightsTermDisplayController < ApplicationController

  def show
    @rights_term = RightsTerm.find_by_param_id(params[:id])
    @work = Work.find_by_friendlier_id(params[:work_id]) if params[:work_id].present?

    unless @rights_term
      raise ActionController::RoutingError.new("No RightsTerm param_id found for `#{params[:id]}`")
    end

    if @work && @work.rights != @rights_term.id
      raise ActionController::RoutingError.new("Can't display contradictory rights page for #{params[:id]} and work #{@work.friendlier_id}")
    end
  end

end
