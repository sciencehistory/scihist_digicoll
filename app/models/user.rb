class User < ApplicationRecord

  # Connects this user object to Blacklights Bookmarks.
  # Do we not need if we're not using Bookmarks? -JR
  # include Blacklight::User

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  #
  # jrochkind did:
  # * comment out registerable, we don't allow registrations
  devise :database_authenticatable,
         :recoverable, :rememberable, :validatable

  has_many :cart_items, dependent: :delete_all
  has_many :works_in_cart, through: :cart_items, source: :work

  # This will correspond to a "role" in the AccessPolicy class.
  # "editor" will replace the current "staff" role.
  # A new "reader" type will be added in a future PR.
  USER_TYPES = %w{admin editor staff_viewer}.freeze
  enum user_type: USER_TYPES.collect {|v| [v, v]}.to_h
  validates :user_type, presence: true

  def admin?
    raise RuntimeError.new("Don't use this method. Use admin_user? instead.")
    user_type == "admin"
  end

  def admin_user?
    user_type == "admin"
  end
  def editor_user?
    user_type == "editor"
  end
  def staff_viewer_user?
    user_type == "staff_viewer"
  end

  # Only used by devise validatable, we want to allow user accounts
  # to be saved with nil password, means they won't be able to log in
  # with any password.
  def password_required?
    false
  end

  # Override of a devise method to lock users out if their individual `locked_out`
  # flag is set, or our global environmental `logins_disabled` flag is set.
  #
  # This should prevent even users who are already logged in from accessing
  # a page requiring authentication.
  def active_for_authentication?
    if locked_out
      false
    elsif ScihistDigicoll::Env.lookup(:logins_disabled)
      false
    else
      super
    end
  end

  def inactive_message
    if locked_out
      "Sorry, your account is disabled."
    elsif ScihistDigicoll::Env.lookup(:logins_disabled)
      "Sorry, logins are temporarily disabled for software maintenance."
    else
      super
    end
  end

  # Method added by Blacklight; Blacklight uses #to_s on your
  # user class to get a user-displayable login/identifier for
  # the account.
  def to_s
    email
  end
end
