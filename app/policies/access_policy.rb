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

    role :admin, proc { |user| user&.admin? } do
      can :see_admin
      can :manage, Kithe::Model
      can :manage, User
      can :destroy, Admin::QueueItemComment do |comment, user|
        comment.user_id == user.id
      end
    end

    role :editor, proc {  user&.editor? } do
      can :see_admin
      can :read, Kithe::Model # whether published or not
      can :update, Kithe::Model
      can :publish, Kithe::Model
    end

    role :viewer, proc { |user| user&.viewer? } do
      can :see_admin
      can :read, Kithe::Model # whether published or not
    end

    role :public do
      can :read, Kithe::Model, { published: true }
    end

  end
end
