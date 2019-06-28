
# TODO: make the model a Work, not a CitableAttributes.
# Renders a citation in HTML from a CitableAttributes, and ruby CSL
#
# Assumes the chicago-note-bibliography CSL style and en-US locale -- lazy loads them
# both globally because they are slow to load.
#
# Does return an html_safe string
#
# @example
#
# CitableAttributes::CitationDisplay.new(citable_attributes).display

class CitationDisplay < ViewModel
  valid_model_type_names 'CitableAttributes'
  # returns an html_safe string
  def display
    csl_data = model.as_csl_json.stringify_keys
    citation_item = CiteProc::CitationItem.new(id: csl_data["id"] || "id") do |c|
      c.data = CiteProc::Item.new(csl_data)
    end
    renderer = CiteProc::Ruby::Renderer.new :format => CiteProc::Ruby::Formats::Html.new,
      :locale => self.class.csl_en_us_locale
    renderer.render(citation_item, self.class.csl_chicago_style.bibliography).html_safe
  end
  # reuse this style cause it's expensive to load. It appears to be concurrency-safe.
  def self.csl_chicago_style
    @csl_chicago_style ||= ::CSL::Style.load("chicago-note-bibliography")
  end
  # similar to csl_chicago_style
  def self.csl_en_us_locale
    @csl_en_us_locale ||= ::CSL::Locale.load("en-US")
  end
end