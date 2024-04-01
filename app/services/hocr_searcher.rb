# Takes a query, finds matches with coordinates and context using HOCR files
# stored in Assets. HOCR is from Tesseract 4.x or 5.x.
#
# TODO:
#      * multi-word "or"
#      * normalize query
#      * search in DB first to identify matches, instead of fetching all into memory
#
class HocrSearcher
  attr_reader :work, :show_unpublished

  def initialize(work, show_unpublished: false, query:)
    @work = work
    @show_unpublished = show_unpublished
    @query = query.downcase
  end

  # @param hocr_nokogiri [Nokogiri::XML::Document] representing an HOCR from Tesserat
  # @return [Array<Nokogiri::XML::Element>] array of Nokogiri::XML::Element representing matching
  #    Tesserct <span class='ocrx_word'>
  #
  # ocrx_word may be vendor-specific to tesseract, but looks like this in Tesseract 4 or 5:
  #
  #     <span class='ocrx_word' id='word_1_25' title='bbox 36 194 91 218; x_wconf 96'>The</span>
  #
  def matching_ocrx_words_for(hocr_nokogiri)
    hocr_nokogiri.search('//*[@class="ocrx_word"]').select {|w| w.text().downcase.include? @query }
  end

  # @return [Array<Hash>], where each hash has a "text" key with html text in context, and
  #   a "osd_rect" key which is a hash with left, top, height, and width in OpenSeadragon units
  #   proportional to image width.
  #
  # example
  #
  #       [{
  #         "text"=>"All {{{units}}} must be connected as above",
  #         "osd_rect"=>{
  #           "left"=>0.38815,
  #           "top"=>0.18576,
  #           "height"=>0.01193,
  #           "width"=>0.04409
  #         }
  #       }]
  #
  def results_for_osd_viewer
    work.members.collect do |member|
      asset = member.leaf_representative

      next unless asset.hocr
      parsed_hocr = Nokogiri::XML(member.hocr) { |config| config.strict }
      next unless parsed_hocr.css(".ocr_page").length >= 1

      matching_ocrx_words_for(parsed_hocr).collect do |ocrx_word|
        {
          "text" => extract_context(ocrx_word),
          "osd_rect" => extract_osd_rect(ocrx_word: ocrx_word, asset: asset)
        }
      end
    end.flatten
  end

  # Take a nokogiri element for an ocrx_word representing a hit, return text showing hit
  # in context, highlighted, for search results.
  #
  # @param ocrx_word_hit [Nokogiri::XML::Element] the element reprenseting a <span class="ocrx_word">, that
  #   is a search hit.
  #
  # @returns text providing that hit in context of surrounding text. The hit itself will be surrounded
  #   by html <mark></mark> tags.  All content will be HTNL-escaped, and html-safe.
  def extract_context(ocrx_word_hit)
    match_id = ocrx_word_hit.attributes["id"].value

    ocrx_word_hit.parent.xpath('*[@class="ocrx_word"]').map do |word|
      (word['id'] == match_id) ? "<mark>#{ERB::Util.html_escape word.text}</mark>" : ERB::Util.html_escape(word.text)
    end.join(' ')
  end

  # Take Tesseract-provided ocrx_word span with bbox, and convert
  # to coordinates that OpenSeadragon.Rect needs for an overlay.
  #
  # * Tessract hocr bbox is *pixels* in original image, x1 (left), y1 (top), x2 (right), y2 (bottom)
  #
  # * OSD uses units based on UNIT 1 is the entire original WIDTH of image. So units are a _portion_ of
  #   original width. And then expressed as top, left, height, width.
  #
  # TODO: Later maybe a rotation too. Tesseract rotation is stored in `ocr_line` span parent.
  #
  # https://en.wikipedia.org/wiki/HOCR#bbox
  #
  # https://kba.github.io/hocr-spec/1.2/#bbox
  #
  # @param ocrx_word [Nokogiri::XML::Element] representing a <span class="ocrx_word"> from Tesseract
  #
  # @param asset [Asset]
  #
  # @return [Hash] with keys :left, :top, :height, :width
  #
  def extract_osd_rect(ocrx_word:, asset:)
    # <span class='ocrx_word' id='word_1_4' title='bbox 1226 515 1327 546; x_wconf 95'>must</span>

    round_digits = 5

    if /bbox (\d+) (\d+) (\d+) (\d+)/ =~ ocrx_word['title']
      x0 = $1.to_f
      y0 = $2.to_f
      x1 = $3.to_f
      y1 = $4.to_f

      unit_value = asset.width.to_f

      {
        'left' =>    (x0 / unit_value).round(round_digits),
        'top'  =>    (y0 / unit_value).round(round_digits),
        'height' =>  ((y1 - y0) / unit_value ).round(round_digits),
        'width' =>   ((x1 - x0) / unit_value ).round(round_digits),
      }
    else
      raise ArgumentError("Could not parse bbox from expected ocrx_word: `#{ocrx_word.to_xml}`")
    end
  end


  private

  def included_members
    @included_members ||= begin
      members = work.members.where(type: "Asset").order(:position)
      members = members.where(published: true) unless show_unpublished
      members.includes(:leaf_representative).select do |member|
        member.leaf_representative &&
        member.leaf_representative.content_type&.start_with?("image/") &&
        member.leaf_representative.stored?
      end
    end
  end

end
