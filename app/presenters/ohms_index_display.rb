# Displays what OHMS calls an "index" that's really more like a "table of contents".
#
# Work of interpreting OHMS XML is done over in OralHistoryContent::OhmsXml#index_points,
# which returns an array of IndexPoint data objects.
#
# Input is our OralHistoryContent::OhmsXml wrapper/helper object.
class OhmsIndexDisplay < ViewModel
  valid_model_type_names "OralHistoryContent::OhmsXml"

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


end
