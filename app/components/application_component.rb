class ApplicationComponent < ViewComponent::Base
  delegate :current_user, to: :helpers

  def can_see_unpublished_items?
	AccessPolicy.new(current_user).can? :see_unpublished_items
  end

end
