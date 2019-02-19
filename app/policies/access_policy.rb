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

    role :admin, { admin: true } do
      can :destroy, Work
      can :publish, Work

      can :destroy, Collection

      can :destroy, Asset

      can :admin, User
    end
  end
end
