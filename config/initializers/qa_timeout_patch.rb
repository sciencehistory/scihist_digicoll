module Qa::Authorities
  # see https://github.com/sciencehistory/scihist_digicoll/issues/2770
  # see https://github.com/devbridge/jQuery-Autocomplete
  # see https://api.jquery.com/jquery.ajax/#jQuery-ajax-settings
  class AssignFast::GenericAuthority < Base
    def response(url)
      space_fix_encoder = AssignFast::SpaceFixEncoder.new
      Faraday.get(url) do |req|
        req.options.params_encoder = space_fix_encoder
        req.headers['Accept'] = 'application/json'
        req.options.timeout = 5
      end
    end
  end
end