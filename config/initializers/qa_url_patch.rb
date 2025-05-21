# http://fast.oclc.org/ is now forwarding to https://fast.oclc.org/, (https) which breaks QA.
# The URL is hard-coded, we need to submit a PR to change that.
# We are currently unable to get the tests on Questioning Authority to pass, so our PRs can't be approved or merged.
#
# For now we're just using a patch.
# If, in a later version, Questioning Authority can read the URL from a settings file, we can remove this patch.
#
# see https://github.com/sciencehistory/scihist_digicoll/issues/2982

SanePatch.patch('qa', '5.14.0') do
  module Qa::Authorities
    class AssignFast::GenericAuthority < Base
      def build_query_url(q)
        escaped_query = clean_query_string q
        index = AssignFast.index_for_authority(subauthority)
        return_data = "#{index}%2Cidroot%2Cauth%2Ctype"
        num_rows = 20 # max allowed by the API

        # sort=usage+desc is not documented by OCLC but seems necessary to get the sort
        # we formerly got without specifying, that is most useful in our use case.
        "https://fast.oclc.org/searchfast/fastsuggest?&query=#{escaped_query}&queryIndex=#{index}&queryReturn=#{return_data}&suggest=autoSubject&rows=#{num_rows}&sort=usage+desc"
      end
    end
  end
end