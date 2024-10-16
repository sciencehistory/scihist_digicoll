class User < ApplicationRecord

  # Connects this user object to Blacklights Bookmarks.
  # Do we not need if we're not using Bookmarks? -JR
  # include Blacklight::User

  # Include default devise modules. Others available are:
  # :confirmable, :lockable, :timeoutable, :trackable and :omniauthable
  #
  # jrochkind did:
  # * comment out registerable, we don't allow registrations

  #  As we switch to single sign-on using Azure,
  #  we're removing 4 devise models as we switch to logging in via Azure:
  #
  #
  #  1) Removing :database_authenticatable
  #     we're now using Azure to log in.
  #
  #  2) Removing :validatable
  #     "validatable module is a group of common validations, which expect a
  #     resource that uses an email/password combination."
  #     See https://github.com/heartcombo/devise/issues/4913
  #
  #  3) Removing :recoverable
  #    We no longer support resetting your password,
  #    since we aren't storing user passwords anymore.
  #
  #  4) Removing :rememberable
  #     You are logged in as long as Azure says you're logged in.
  devise :omniauthable, omniauth_providers: %i[azure_activedirectory_v2]


  # We're removing :validatable, which used to do email validation.
  # Let's add a couple of validations from
  # https://github.com/heartcombo/devise/blob/main/lib/devise/models/validatable.rb:
  validates_presence_of   :email
  validates_uniqueness_of :email, allow_blank: true, case_sensitive: true, if: :devise_will_save_change_to_email?
  validates_format_of     :email, with: URI::MailTo::EMAIL_REGEXP, allow_blank: true, if: :devise_will_save_change_to_email?


  has_many :cart_items, dependent: :delete_all
  has_many :works_in_cart, through: :cart_items, source: :work

  # This will correspond to a "role" in the AccessPolicy class.
  USER_TYPES = %w{admin editor staff_viewer}.freeze
  enum :user_type, USER_TYPES.collect {|v| [v, v]}.to_h
  validates :user_type, presence: true

  def admin_user?
    user_type == "admin"
  end
  def editor_user?
    user_type == "editor"
  end
  def staff_viewer_user?
    user_type == "staff_viewer"
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
