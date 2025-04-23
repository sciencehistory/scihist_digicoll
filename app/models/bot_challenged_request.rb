class BotChallengedRequest < ApplicationRecord

  #  bin/rails runner 'BotChallengedRequest.trim_old'
  def self.trim_old(since: 2.weeks.ago)
    self.where("created_at <= ?", since).delete_all
  end


  def self.save_from_request!(request)
    self.create!(
      path: request.filtered_path,
      request_id: request.request_id,
      client_ip: request.ip,
      user_agent: request.user_agent,
      normalized_user_agent: CompactUserAgent.new(request.user_agent).compact,
      # http headers, but not cookie, it's encrypted and long and useless
      headers: request.headers.find_all {|k, v| k.start_with?("HTTP_") && k != "HTTP_COOKIE"}.to_h
    )
  end
end
