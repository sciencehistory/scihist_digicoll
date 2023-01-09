# Policy for access-granted.
# https://github.com/chaps-io/access-granted
# https://github.com/chaps-io/access-granted/wiki/Role-based-authorization-in-Rails
class AccessPolicy
  include AccessGranted::Policy
  # :publish and :admin are only defined in our code.
  # as is :access_staff_viewer_functions.
  # 
  # The :admin, :editor and :staff_viewer roles are cumulative:
  # e.g. if the :staff_viewer role can do something, so can :editor and :admin.
  #
  # If you edit this file, please also update 
  # spec/policies/access_policy_spec.rb
  def configure
    role :admin, proc { |user| has_admin_permissions?(user) } do
      can :admin, User
      can :destroy, Kithe::Model
    end

    role :editor, proc { |user| has_editor_permissions?(user) } do
      can [:create, :update, :publish], Kithe::Model
    end

    role :staff_viewer, proc { |user| has_staff_viewer_permissions?(user) } do
      can :read, Kithe::Model # published or not
      can :destroy, Admin::QueueItemComment do |comment, user|
        comment.user_id == user.id
      end
      can :access_staff_functions
    end

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

  # Makes a common pattern easier to understand and use.
  # Call `current_policy.can_see_unpublished_records?` from anywhere,
  # or we have a rails helper by the same name for convenience too.
  def can_see_unpublished_records?
    can? :read, Kithe::Model
  end

  private

  def has_admin_permissions?(user)
    user&.admin_user?
  end
  
  def has_editor_permissions?(user)
    user&.admin_user? || user&.editor_user?
  end
  
  def has_staff_viewer_permissions?(user)
    user&.admin_user? || user&.editor_user? || user&.staff_viewer_user?
  end

end