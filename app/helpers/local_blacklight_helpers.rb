module LocalBlacklightHelpers
  # A Blacklight facet field helper_method; maps rights URI to String
  # @param [String] facet field uri value
  # @return [String] rights statement label
  def rights_label(rights_url)
    # If not found, just return the original rights_url, to have an
    # easier to debug failure mode.
    RightsTerms.label_for(rights_url) || rights_url
  end
end
