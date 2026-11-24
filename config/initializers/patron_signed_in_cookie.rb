# A non-HttpOnly flag cookie, so JS can show patron sign-in state in the masthead while page
# HTML stays the same for everyone, and cacheable. No personal data. Can go stale (eg
# session_token rotated), worst case it shows account links that lead to sign-in.

# runs on every request too (:fetch), sliding expiry along with the session timeout
Warden::Manager.after_set_user scope: :patron do |patron, warden, opts|
  ActionDispatch::Request.new(warden.env).cookie_jar[Patron::SIGNED_IN_FLAG_COOKIE] = {
    value: "1",
    expires: Patron::SESSION_EXPIRE_PERIOD.from_now,
    httponly: false,
    same_site: :lax
  }
end

Warden::Manager.before_logout scope: :patron do |patron, warden, opts|
  ActionDispatch::Request.new(warden.env).cookie_jar.delete(Patron::SIGNED_IN_FLAG_COOKIE)
end
