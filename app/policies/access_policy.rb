# for access-granted gem
#
# All our accounts are staff accounts, so we don't bother defining permissions
# for standard staff.
#
# But we define the elevated permissions for administrative staff.
class AccessPolicy
  include AccessGranted::Policy

  def configure

    role :admin, proc { |user| user&.admin_user? } do
      can [:destroy, :publish], Kithe::Model
      can :access_staff_functions
      can :admin, User
    end

    role :staff, proc { |user| !user.nil? } do
      can [:read, :update], Kithe::Model # whether published or not
      can :access_staff_functions
      can :destroy, Admin::QueueItemComment do |comment, user|
        comment.user_id == user.id
      end
    end

    # This role can read published Kithe::Models.
    role :public do
      can :read, Kithe::Model do |mod, user|
        # mod could be any of Kithe::Model, Collection, Work, Asset,
        # *or* an instance of any of the above classes. (mod.kind_of?(Kithe::Model))
        #
        # If mod is any of the above classes, definitely return false:
        # the public is not allowed to read *all* possible instances of any of these classes.
        #
        # If mod is an instance, return true only if the instance is published.
        mod.kind_of?(Kithe::Model) && mod.published?
      end
    end

  end

  # This is a bit confusing the way we check this with access_granted,
  # so DRY it up in one place. You can call `current_policy.can_see_unpublished_records?` anywhere,
  # or we have a rails helper for convenience too.
  def can_see_unpublished_records?
    can? :read, Kithe::Model
  end
end
