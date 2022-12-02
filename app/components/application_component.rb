class ApplicationComponent < ViewComponent::Base
  delegate :current_user, :can?, to: :helpers
  # def access_policy
  #   @access_policy ||= AccessPolicy.new(current_user)
  # end
end
