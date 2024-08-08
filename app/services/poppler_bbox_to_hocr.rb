# The poppler `pdftotext` command can extract text from a PDF, with "bbox-layout" info. This is similar to HOCR
# format, but not exactly the same.
#
# This class can translate from poppler bbox output to HOCR, specifically HOCR matching the struture
# tesseract 5.x creates (differnet tools create different kinds of HOCR!)
#
# Eg, output of poppler tool from pdftotext with -bbox-layout (not just -bbox!)
#
#     pdftotext -bbox-layout file.pdf -f $FIRST_PAGE -l $LAST_PAGE output.bbox.xml
#
# Converts to something SIMILAR to what you'd get from tesseract with:
#
#     tesseract file.tiff outputfile  -l eng hocr
#
#   * It has less info, because some things tesseract includes are not applicable or not available, but
#     should use the same tags for the info there.
#
#   * Specifically, pdftotext does not do paragraph segmentation, so our output will not have
#     <p class='ocr_par'> tags
#
#
# For example intput and output see specs
#
# @example PopplerBboxToHocr.new(bbox_layout_doc_string).transformed_to_hocr
#
# ## DPI
#
# PDFs internal dimensions are always 72 dpi.  So the bbox produced by pdftotext will have pixels as if 72 dpi.
#
# But you may want the HOCR to go along with a different dpi. While `pdftotext` has a `--dpi` argument -- it
# doesn't succesfully change the page dimensions itself.
#
# So instead you can use the dpi argument here.  Let's say you have a PDF, and you extracted a page image with:
#
#     vips copy original.pdf[page=0,dpi=300] page1.300dpi.jpeg
#
#  And you extracted text (without using --dpi arg!) with:
#
#     pdftotext -bbox-layout original.pdf -f 1 -l 1 output.bbox-layout.xml
#
#  If you want to get hocr that has pixel dimensions and coordinates that match your jpeg output,
#  just pass that same DPI you used in the vips command to this object:
#
#      PopplerBboxToHocr.new(bbox_string, dpi: 300).transformed_to_hocr
#
class PopplerBboxToHocr
  XHTML_NS = "http://www.w3.org/1999/xhtml"

  attr_reader :xml, :dpi, :meta_tags

  # @param meta_tags [Hash] if you'd like to insert additional <meta> tags into the hocr output,
  #                         pass in hash with key 'name' attribute and value `content' attribute.
  def initialize(bbox_string, dpi: nil, meta_tags: {})
    @xml = Nokogiri::XML(bbox_string)
    @dpi = dpi
    @meta_tags = meta_tags

    @page_id_counter = 0
    @block_id_counter = 0
    @par_id_counter = 0
    @line_id_counter = 0
    @word_id_counter = 0
  end

  def transformed_to_hocr_nokogiri
    @transformed ||= begin
      transform!
      @xml
    end
  end

  def transformed_to_hocr
    transformed_to_hocr_nokogiri.to_xml
  end

  protected

  def transform!
    xml.encoding = 'UTF-8'

    # # just remove doc tag
    unwrap!("//x:doc", { x: XHTML_NS })

    xml.xpath("//x:page", x: XHTML_NS).each do |page_node|
      width = page_node["width"].to_f
      height = page_node["height"].to_f

      if dpi
        width = width / 72.0 * dpi
        height = height / 72.0 * dpi
      end

      remove_all_attributes!(page_node)

      page_node.name = "div"
      page_node["class"] = "ocr_page"
      page_node["id"] = "page_#{@page_id_counter += 1}"
      page_node["title"] = "bbox 0 0 #{width.round} #{height.round}"
    end

    # # remove it and just unwrap it's children, no equiv in tesseract hocr
    unwrap!("//x:flow", { x: XHTML_NS })

    # block goes to ocr_carea to match tesseract, although some think this is
    # a tesseract bug and it shoudl be ocrx_block
    # https://groups.google.com/g/tesseract-ocr/c/djenIdI5EbI
    xml.xpath("//x:block", x: XHTML_NS).each do |block_node|
      bbox = hocr_bbox_from(block_node)

      remove_all_attributes!(block_node)

      block_node.name = "div"
      block_node["class"] = "ocr_carea"
      block_node["id"] = "block_#{@page_id_counter}_#{@block_id_counter += 1}"
      block_node["title"] = bbox
    end

    xml.xpath("//x:line", x: XHTML_NS).each do |line_node|
      bbox = hocr_bbox_from(line_node)

      remove_all_attributes!(line_node)

      line_node.name = "div"
      line_node["class"] = "ocr_line"
      line_node["id"] = "line_#{@page_id_counter}_#{@line_id_counter += 1}"
      line_node["title"] = bbox
    end

    xml.xpath("//x:word", x: XHTML_NS).each do |word_node|
      bbox = hocr_bbox_from(word_node)

      remove_all_attributes!(word_node)

      word_node.name = "div"
      word_node["class"] = "ocrx_word"
      word_node["id"] = "word_#{@page_id_counter}_#{@word_id_counter += 1}"
      word_node["title"] = bbox
    end

    # add meta tags
    if meta_tags.present?
      head = xml.at_xpath("//x:head", x: XHTML_NS)
      meta_tags.each do |name, content|
        meta = h3 = Nokogiri::XML::Node.new "meta", xml
        meta["name"] = name
        meta["content"] = content
        head.add_child(meta)
        head.add_child("\n")
      end
    end
  end

  # takes a poppler node with attributes xMin, yMin, xMax, and yMax
  #
  # converts to an hocr bbox label.
  #
  # Rounds to nearest integer pixel.
  #
  def hocr_bbox_from(block_node)
    xMin, yMin, xMax, yMax = block_node['xMin'].to_f, block_node['yMin'].to_f, block_node['xMax'].to_f, block_node['yMax'].to_f

    if dpi
      xMin = xMin / 72.0 * dpi
      yMin = yMin / 72.0 * dpi
      xMax = xMax / 72.0 * dpi
      yMax = yMax / 72.0 * dpi
    end

    "bbox #{xMin.round} #{yMin.round} #{xMax.round} #{yMax.round}"
  end

  def remove_all_attributes!(node)
    node.attributes.keys.each {|k| node.remove_attribute(k) }
  end

  # remove matching nodes, unwrapping their children to be directly in the doc
  def unwrap!(selector, ns)
    xml.xpath(selector, **ns).each do |node|
      node.children.each do |child|
        child.parent = node.parent
      end
      node.remove
    end
  end
end
