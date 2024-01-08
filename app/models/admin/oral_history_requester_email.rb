# Sort of represents an Oral Hsitory Requester (for non-public OH's), but really
# just the email
#
# -- we let people request without authenticating, so all we know is the
# email they specified -- names and other things are attached to individual requests,
# becuase we don't know they are authorized to overwrite OR SEE any existing info
# at time of request!
#
# But this is the record that logins (really one-time magic link logins)
# are attached to, that DO confirm the user has access to the email specified!
class Admin::OralHistoryRequesterEmail < ApplicationRecord
  LOGIN_LINK_EXPIRE = 7.days

  # we don't have uniqueness validation cause it's incompatible with using create_or_find_by which
  # we want to.
  validates :email, presence: true

  has_many :oral_history_access_requests

  generates_token_for :auto_login, expires_in: LOGIN_LINK_EXPIRE do
    # if email changes, link should no longer be good.
    # other things can be put in here if you wanted to make the link expirable
    # or single-user or what have you, whatever you put in here has to remain
    # constant for token to be good.
    email
  end
end
