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

    role :public do
      can :read, Kithe::Model, { published: true }
    end

  end
end
