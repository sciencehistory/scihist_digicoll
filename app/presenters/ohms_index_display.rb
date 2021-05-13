# Displays what OHMS calls an "index" that's really more like a "table of contents".
#
# Work of interpreting OHMS XML is done over in OralHistoryContent::OhmsXml#index_points,
# which returns an array of IndexPoint data objects.
#
# Input is our OralHistoryContent::OhmsXml wrapper/helper object.
#
# Also need to pass in a Work, so we can generate direct links to segments.
class OhmsIndexDisplay < ViewModel
  valid_model_type_names "OralHistoryContent::OhmsXml"
  attr_reader :work

  def initialize(ohms_xml, work:)
    super(ohms_xml)
    @work = work
  end

  def display
    render "/presenters/ohms_index", model: model, view: self
  end

  def index_points
    model.index_points
  end

  # just changes \n to <br> while maintaining html safety.
  # That seems to match OHMS standard viewer.
  def format_partial_transcript(str)
    safe_join(str.split("\n").collect {|s| [s, "<br>".html_safe]}.flatten)
  end

  def accordion_element_id(index)
    "ohmsAccordionElement#{index}"
  end

  def accordion_header_id(index)
    "ohmsAccordionHeader#{index}"
  end

  # The whole 'card' element we use as a target for search results
  def accordion_wrapper_id(index)
    "ohmsAccordionCard#{index}"
  end

  def share_link_area_id(index)
    "ohmsTocShareLink#{index}"
  end

  def direct_to_segment_link(index_point)
    work && work_url(work, anchor: "t=#{index_point.timestamp}&tab=ohToc".html_safe)
  end



end
