# Print friendly versions of HOCR.
class HocrComponent < ApplicationComponent
  attr_reader :raw_hocr

  def initialize(raw_hocr)
    @raw_hocr = raw_hocr
  end

  # HOCR With tags, but with ids stripped out. Several of these
  # can be printed in HTML without causing colliding ids.
  def html_body_without_ids
    doc = Nokogiri::HTML(@raw_hocr) { |config| config.strict }
    body =  doc.css('body')[0]
    body.xpath('//@id').remove
    body.children.to_html.html_safe
  end
end
