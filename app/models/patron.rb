# A public patron, identified by email, who registers for or requests non-public Oral Histories.
#
# We let people register/request without authenticating, so name/institution from an
# unauthenticated form are only ever used to fill in a NEW patron, never to overwrite an
# existing one -- see .find_or_create_from_form.
#
# Logins are via emailed magic links, which also confirm the patron owns the email.
class Patron < ApplicationRecord
  # old legacy table name, cumbersome to change table name
  # without downtime, but we should do it at some point to avoid confusion
  # eg https://docs.gitlab.com/ee/development/database/rename_database_tables.html
  self.table_name = "oral_history_requester_emails"

  normalizes :email, with: -> email { email.downcase.strip }

  LOGIN_LINK_EXPIRE = 7.days
  SESSION_EXPIRE_PERIOD = 30.days

  # Login is via magic link in OralHistorySessionsController, devise handles the session.
  devise :rememberable, :timeoutable,
    remember_for: SESSION_EXPIRE_PERIOD,
    extend_remember_period: true,
    expire_all_remember_me_on_sign_out: false,
    timeout_in: SESSION_EXPIRE_PERIOD

  has_encrypted :name, :institution, :registration_reason

  # we don't have uniqueness validation cause it's incompatible with using create_or_find_by which
  # we want to.
  validates :email, presence: true
  validates :name, presence: true, on: :create

  # legacy foreign key name, sorry
  has_many :oral_history_requests, foreign_key: "oral_history_requester_email_id"

  generates_token_for :auto_login, expires_in: LOGIN_LINK_EXPIRE do
    # if email changes, link should no longer be good.
    # other things can be put in here if you wanted to make the link expirable
    # or single-user or what have you, whatever you put in here has to remain
    # constant for token to be good.
    email
  end

  # Finds patron by email, or creates one with the other attributes. An existing patron's
  # attributes are never changed, since the form is unauthenticated.
  #
  # @return [Patron] persisted, or new record with validation errors if it couldn't be created
  def self.find_or_create_from_form(email:, **attributes)
    patron = find_by(email: normalize_value_for(:email, email))
    return patron if patron

    patron = new(email: email, **attributes)
    return patron unless patron.valid?

    create_or_find_by!(email: patron.email) { |p| p.assign_attributes(attributes) }
  end

  # Same names as devise :confirmable, in case we switch to it. We confirm on magic-link login,
  # since clicking an emailed link proves the patron owns the email.
  def confirmed?
    confirmed_at.present?
  end

  def confirm!
    update!(confirmed_at: Time.current)
  end

  # No password, so devise session and remember-me cookies are validated against session_token;
  # rotate it to log a patron out everywhere.
  def authenticatable_salt
    session_token
  end

  def rememberable_value
    session_token
  end

  # Can see this OH and it's assets in full: direct to anyone; by-request if confirmed and automatic or approved.
  # @param [Work]
  def can_access_oral_history?(work)
    return false unless work.published?

    oh = work.oral_history_content
    return true if oh.nil? || oh.availability_direct? # no sidecar means direct
    return false unless confirmed? && oh.available_by_request?

    oh.availability_automatic_request? ||
      OralHistoryRequest.where(work: work, patron: self, delivery_status: ["approved", "automatic"]).exists?
  end
end
