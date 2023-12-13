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
  self.filter_attributes += [ :email ]

  self.filter_attributes += [ :email ]

  # we don't have uniqueness validation cause it's incompatible with using create_or_find_by which
  # we want to.
  validates :email, presence: true

  has_many :oral_history_access_requests
end
