# placeholder
class OnDemandDerivativeCreatorJob < ApplicationJob
  queue_as :on_demand_derivatives

  # This really will perform work to create the derivative, regardless of status --
  # whoever enqueued the job is responsible for not enqueing it if we have had an
  # error and haven't waited the timeout period, etc.
  def perform(work, derivative_type)
    OnDemandDerivativeCreator.new(work, derivative_type: derivative_type).attach_derivative!
  end
end
