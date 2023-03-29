# Some static utility methods for printing friendly versions of HOCR .
class HocrHelper
  # Just the text content of the body. No tags.
  def self.text_content_as_string(raw_hocr)
    doc = Nokogiri::HTML(raw_hocr) { |config| config.strict }
    doc.xpath('//@*').remove
    body =  doc.css('body')[0]
    body.content.squish
  end

  # With tags, but with ids stripped out. Several of these
  # can be printed in HTML without causing colliding ids.
  def self.html_body_without_ids(raw_hocr)
    doc = Nokogiri::HTML(raw_hocr) { |config| config.strict }
    body =  doc.css('body')[0]
    body.xpath('//@id').remove
    body.children.to_html.html_safe
  end
end