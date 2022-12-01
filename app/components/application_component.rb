class ApplicationComponent < ViewComponent::Base
  delegate :current_user, to: :helpers

  def can_access_staff_functions?
       AccessPolicy.new(current_user).can? :access_staff_functions
  end
end
