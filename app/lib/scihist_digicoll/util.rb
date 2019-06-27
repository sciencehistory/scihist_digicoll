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

    # Just take a bib number and produce a URL to our OPAC, using opac link template
    # from ENV.
    def self.opac_url(bib_number)
      ScihistDigicoll::Env.lookup(:opac_link_template).sub("%s", ERB::Util.url_encode(bib_number))
    end

    # Turn a content-type into a string we can show to a user, like 'application/pdf' to 'PDF'.
    #
    # For now, it's kind of rough, and relies on types registered with Rails Mime::Type
    # (see config/initializers/mime_types.rb), and assumes all caps of the extension is good.
    #
    # Maybe we should use explicit i18n instead.
    #
    # If nothing found registered with Rails Mime::Type, will return input.
    def self.humanized_content_type(content_type)
      mime_obj = Mime::Type.lookup(content_type)
      return content_type unless mime_obj && mime_obj.symbol

      mime_obj.symbol.to_s.upcase
    end
  end
end
