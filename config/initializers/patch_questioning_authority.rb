# The OCLC AssignFast service now needs a 'sort' param to get behavior we want.
#
# Until/unless we get this behavior into QuestioningAuthority gem, we will patch it to add it.
#
# https://github.com/sciencehistory/scihist_digicoll/issues/2650

module PatchQAAssignFast
  def build_query_url(...)
    result = super

    # be super careful
    unless result.include?('sort=usage+desc')
      result += '&sort=usage+desc'
    end

    result
  end
end


Qa::Authorities::AssignFast::GenericAuthority.prepend PatchQAAssignFast
