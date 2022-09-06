class RelatedLinkFilter
  attr_reader :input_related_links, :general_related_links, :finding_aid_related_links

  # TODO data migration to normalize the old /concern/generic_works/ urls
  RELATED_WORK_PREFIX_RE = %r{\A\s*https?://digital\.sciencehistory\.org/(works/|concern/generic_works/)}

  def initialize(input_related_links)
    @input_related_links = (input_related_links || [])
  end

  # @return [Array<RelatedLink>] suitable for display in our standard list of
  #    eg under "Learn More" heading. Does not include special purpose
  #    categories.
  def general_related_links
    @general_related_links ||= input_related_links.find_all { |rl| ! rl.category.in?(%w{related_work finding_aid})}
  end

  def finding_aid_related_links
    @finding_aid_related_links ||= input_related_links.find_all { |rl|  rl.category == "finding_aid" }
  end

  # Take the ID out of the URL for any work URL referencing our app. It's a friendlier_id
  # cause that's what we use in our URLs.
  def related_work_friendlier_ids
    @related_work_friendlier_ids ||= input_related_links.find_all { |rl|  rl.category == "related_work" }.
                                                         map { |rl| rl.url&.sub(RELATED_WORK_PREFIX_RE, '')}.
                                                         compact
  end
end
