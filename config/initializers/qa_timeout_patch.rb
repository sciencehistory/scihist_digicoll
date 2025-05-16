# We want our calls to https://fast.oclc.org/ to time out after five seconds.
#
# In April 2025, Eddie Rubeiz did create a PR for Questioning Authority to allow for this
# ( see https://github.com/samvera/questioning_authority/pull/397 )
# but we are unable to get the tests on Questioning Authority to pass, so the PR can't be approved or merged.
#
# For now we're just using a patch.
#
# If, in a later version of Questioning Authority, the PR is approved, we can remove this patch and just
# change the settings as described in the PR to set the timeout below.
#
#
# see https://github.com/sciencehistory/scihist_digicoll/issues/2770
# see https://github.com/devbridge/jQuery-Autocomplete
# see https://api.jquery.com/jquery.ajax/#jQuery-ajax-settings

SanePatch.patch('qa', '5.14.0') do
  module Qa::Authorities
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
end