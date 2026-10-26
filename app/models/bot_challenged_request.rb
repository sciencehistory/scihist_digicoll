class BotChallengedRequest < ApplicationRecord

  #  bin/rails runner 'BotChallengedRequest.trim_old'
  def self.trim_old(since: 2.weeks.ago)
    self.where("created_at <= ?", since).delete_all
  end


  def self.save_from_request!(request)
    # bots send invalid UTF-8, which postgres refuses to store
    user_agent = scrub(request.user_agent)

    self.create!(
      path: scrub(request.filtered_path),
      request_id: scrub(request.request_id),
      client_ip: request.ip,
      user_agent: user_agent,
      normalized_user_agent: CompactUserAgent.new(user_agent).compact,
      # http headers
      # but not cookie, it's encrypted and long and useless. Or things we're already
      # including in their own columns, or otherwise uninteresting.
      headers: request.headers.find_all do |k, v|
        k.start_with?("HTTP_") && ! k.in?(["HTTP_COOKIE", "HTTP_USER_AGENT", "HTTP_CONNECTION", "HTTP_X_REQUEST_ID", "HTTP_VIA"])
      end.to_h.transform_values { |v| scrub(v) }
    )
  end

  # weird bots gave us weird values in headers, which Postgres ended up error'ing on,
  # giving us error alerts. Let's try to scrub bad bytes for encoding, assume
  # UTF-8 if the string has no encoding (you can't scrub binary)
  def self.scrub(value)
    return value unless value.is_a?(String)

    value = value.dup.force_encoding("UTF-8") if value.encoding == Encoding::ASCII_8BIT
    value.scrub
  end
end
