module ScihistDigicoll
  module Util
    # inspired by code at
    # https://github.com/perfectline/validates_url/blob/b170db5a211b7e277c76727a46559c36b989e430/lib/validate_url.rb
    #
    # We make sure it's http or https, and the domain name has at least one dot in it.
    def self.valid_url?(str)
      uri = URI.parse(str)
      return !!(uri && uri.host && ["http", "https"].include?(uri.scheme) && uri.host.include?('.'))
    rescue URI::InvalidURIError
      return false
    end
  end
end
