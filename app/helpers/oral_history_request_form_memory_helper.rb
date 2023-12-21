# This stores Oral History request form entries so we can pre-fill form on subsequent
# requests.
#
# THIS IS SENSITIVE PATRON INFO.  But we do want to remember it to pre-fill.
# We store it ENCRYPTED so only the back-end app can decrypt it; and also
# set it to be http-only (not accessible by JS).
#
# We set a 1 day expiration, although every time they fill out a form the cookie
# will get re-written and bumped.
#
# it is important we remember this info is for pre-filling form only -- it is of course
# not auth, just cause a user says they have an email address doens't mean they should
# get access to ANY personal info of past requests in our system from that email addr!
module OralHistoryRequestFormMemoryHelper
  COOKIE_KEY = "_scihist_digicoll_oh_request_entries"
  TTL = 1.day
  ALLOWED_KEYS = %w{patron_name patron_email patron_institution intended_use oral_history_requester_email}

  def oral_history_request_form_entry_read
    JSON.parse( cookies.signed[COOKIE_KEY] || "{}").slice(*ALLOWED_KEYS)
  rescue JSON::ParserError
    {}
  end

  def oral_history_request_form_entry_write(json_hash)
    cookies.signed[COOKIE_KEY] = {
      value: JSON.generate(json_hash.slice(*ALLOWED_KEYS)),
      expires: TTL,
      httponly: true,
      # for tests to work, have to have non-https cookies in test and dev!
      secure: Rails.env.production?
    }
  end
end
