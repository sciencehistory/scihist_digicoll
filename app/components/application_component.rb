class ApplicationComponent < ViewComponent::Base
  delegate :current_user, to: :helpers

  def can_see_admin_pages?
       AccessPolicy.new(current_user).can? :see_admin_pages
  end
end
