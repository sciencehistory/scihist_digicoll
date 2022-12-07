# for access-granted gem
#
# All our accounts are staff accounts, so we don't bother defining permissions
# for standard staff.
#
# But we define the elevated permissions for administrative staff.
class AccessPolicy
  include AccessGranted::Policy

  def configure
    # The most important admin role, gets checked first

    role :admin, proc { |user| !user.nil? && user.admin_user? } do
      can :destroy, Work
      can :publish, Work

      can :destroy, Collection
      can :publish, Collection

      can :destroy, Asset
      can :publish, Asset

      can :admin, User
    end

    # Any logged-in staff considered staff at present
    role :staff, proc { |user| !user.nil? } do

      can :read, Work
      can :update, Work

      can :read, Collection
      can :update, Collection

      can :read, Asset
      can :update, Asset

      can :access_staff_functions
      can :destroy, Admin::QueueItemComment do |comment, user|
        comment.user_id == user.id
      end

    end

    role :public do
      can :read, Kithe::Model, { published: true }
    end
  end

  # This is a bit confusing the way we check this with access_granted,
  # so DRY it up in one place. You can call `current_policy.can_see_unpublished_records?` anywhere,
  # or we have a rails helper for convenience too.
  def can_see_unpublished_records?
    (can? :read, Asset) && (can? :read, Work)
  end
end
