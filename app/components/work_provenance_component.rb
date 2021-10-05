# Display the provenance of a work on the front end:
# WorkProvenanceComponent.new(work.provenance).display
class WorkProvenanceComponent < ApplicationComponent
  attr_reader :provenance_attribute

  def initialize(provenance_attribute)
    @provenance_attribute = provenance_attribute
    @provenance_summary, @provenance_notes = split_provenance(@provenance_attribute) if @provenance_attribute.present?
  end

  def render?
    provenance_attribute.present?
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
  def split_provenance(source_attr)
    source_attr.split(/\s*\n\s*(?:NOTES|Notes):?\s*\n\s*/, 2)
  end

end
