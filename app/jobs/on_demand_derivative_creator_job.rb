# placeholder
class OnDemandDerivativeCreatorJob < ApplicationJob
  queue_as :on_demand_derivatives

  def perform(work, derivative_type)
    OnDemandDerivativeCreator.new(work, derivative_type: derivative_type).attach_derivative!
  end
end
