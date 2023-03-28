module HocrHelper

  # Just the text content of the body. No tags.
  def text_content_as_string(raw_hocr)
    doc = Nokogiri::HTML(raw_hocr) { |config| config.strict }
    doc.xpath('//@*').remove
    body =  doc.css('body')[0]
    body.content.squish
  end

  # With tags, but with ids stripped out. Several of these
  # can be printed in HTML without causing colliding ids.
  def html_body_without_ids(raw_hocr)
    doc = Nokogiri::HTML(raw_hocr) { |config| config.strict }
    body =  doc.css('body')[0]
    body.xpath('//@id').remove
    body.children.to_html
  end

end