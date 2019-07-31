# placeholder
class OnDemandDerivativeCreatorJob < ApplicationJob
  def perform(work, derivative_type)
    OnDemandDerivativeCreator.new(work, derivative_type: derivative_type).attach_derivative!
  end
end
