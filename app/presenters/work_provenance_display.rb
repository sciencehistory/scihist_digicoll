# Display the provenance of a work on the front end:
# WorkProvenanceDisplay.new(work).display
class WorkProvenanceDisplay < ViewModel
  valid_model_type_names 'Work'
  def display
    return "" if model.provenance.blank?
    @provenance_summary, @provenance_notes = split_provenance
    render "/presenters/work_provenance", model: model, view: self
  end

  def provenance_summary
    DescriptionDisplayFormatter.new(@provenance_summary).format
  end

  def provenance_notes
    DescriptionDisplayFormatter.new(@provenance_notes).format
  end

  private

  # To split the provenance field into regular provenance info and a set of notes,
  # use as a delimiter the string NOTES, in all caps, followed by an optional colon.
  #
  # The regular expression also captures extra blank space
  # before and after the match, as well as before and after the word "NOTES".
  def split_provenance
    model.provenance.split(/\s*\n\s*(?:NOTES|Notes):?\s*\n\s*/, 2)
  end

end
