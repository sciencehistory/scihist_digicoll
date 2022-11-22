# for access-granted gem
#
# All our accounts are staff accounts, so we don't bother defining permissions
# for standard staff.
#
# But we define the elevated permissions for administrative staff.
class AccessPolicy
  include AccessGranted::Policy

  def configure
    role :admin, proc { |user| user&.admin? } do
      can :see_admin
      can :manage, Kithe::Model
      can :manage, User
      can :destroy, Admin::QueueItemComment do |comment, user|
        comment.user_id == user.id
      end
      can :manage, InterviewerProfile
      can :manage, IntervieweeBiography
      can :manage, Admin::DigitizationQueueItem
    end

    role :editor, proc {  user&.editor? } do
      can :see_admin

      can :read, Kithe::Model # whether published or not
      can :update, Kithe::Model
      can :publish, Kithe::Model
      
      can :manage, InterviewerProfile
      can :manage, IntervieweeBiography
      can :manage, Admin::DigitizationQueueItem
    end

    role :viewer, proc { |user| user&.viewer? } do
      can :see_admin
      
      can :read, Kithe::Model # whether published or not
      
      can :read, InterviewerProfile
      can :read, IntervieweeBiography
      can :read, Admin::DigitizationQueueItem
    end

    role :public do
      # TODO:
      # Deleting this line has no effect
      # on any user's permissions.
      #
      # Conversely, adding it to the role
      # of the active user causes an error.
      can :read, Kithe::Model, { published: true }
    end

  end
end
