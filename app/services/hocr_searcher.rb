# Takes a query, finds matches with coordinates and context using HOCR files
# stored in Assets. HOCR is from Tesseract 4.x or 5.x.
#
# Our search semantics right now are:
#
#   * case insensitive
#
#   * For the most part only match exact matches, although we do some stripping of
#     punctuation at edges of words
#
#   * partial word matches are allowed, but has to match "starts with" at beginning of word
#
#   * multi-word queries turn into just separate word matches, finding/highlighting an of those words
#
class HocrSearcher
  class EmptyQueryError < ArgumentError ; end

  attr_reader :work, :show_unpublished, :query

  def initialize(work, show_unpublished: false, query:)
    @work = work
    @show_unpublished = show_unpublished
    @query = normalize_query(query)

    if @query.empty?
      raise EmptyQueryError.new("Normalized query is empty for query `#{query}`")
    end
  end

  # Normalizes query for searching, spliting into separate tokens, downcase, and maybe
  # removing some punctuation. Unicode normalize NFC, which we hope matches HOCR.
  #
  # @param query [String]
  # @erturn [Array<String>]
  def normalize_query(query)
    # phrase searches not supported, double quotes gonna do nothing but mess us up...
    # let's remove all punctuation at beginning or end of token, but not internal
    # (don't want to mess up `isn't`)

    query.downcase.split(/\s+/).collect(&:presence).compact.
      collect { |token| token.gsub(/\A[[:punct:]]+|[[:punct:]]+$/, '')}.
      collect { |token| token.presence }.compact. # eliminate any empty strings
      collect { |token| token.unicode_normalize }
  end

  # @return [Array<Hash>], where each hash has a "text" key with html text in context, and
  #   a "osd_rect" key which is a hash with left, top, height, and width in OpenSeadragon units
  #   proportional to image width.
  #
  # example
  #
  #       [{
  #         "text"=>"All {{{units}}} must be connected as above",
  #         "id" => "adf8a7dfa",
  #         "osd_rect"=>{
  #           "left"=>0.38815,
  #           "top"=>0.18576,
  #           "height"=>0.01193,
  #           "width"=>0.04409
  #         }
  #       }]
  #
  def results_for_osd_viewer
    identified_members.collect do |member|
      asset = member.leaf_representative

      next unless asset.hocr
      parsed_hocr = Nokogiri::XML(asset.hocr) { |config| config.strict }
      next unless parsed_hocr.css(".ocr_page").length >= 1

      matching_ocrx_words_for(parsed_hocr).collect do |ocrx_word|
        {
          "id"  => member.friendlier_id, # for child works, viewer uses the direct member id
          "text" => extract_context(ocrx_word),
          "osd_rect" => extract_osd_rect(ocrx_word: ocrx_word, asset: asset)
        }
      end
    end.flatten.compact
  end

  # @param hocr_nokogiri [Nokogiri::XML::Document] representing an HOCR from Tesserat
  #
  # @return [Array<Nokogiri::XML::Element>] array of Nokogiri::XML::Element representing matching
  #    Tesserct <span class='ocrx_word'>
  #
  # ocrx_word may be vendor-specific to tesseract, but looks like this in Tesseract 4 or 5:
  #
  #     <span class='ocrx_word' id='word_1_25' title='bbox 36 194 91 218; x_wconf 96'>The</span>
  #
  # We want ones where one of our query words matches only at BEGINNING OF WORD, case insensitively
  #
  # There may be pages returned by our original postgres filter that were false positives,
  # for instance matching XML tags instead of text, or for any other reason --
  # this logic here, operating on parsed XML text should filter out false positives and only match what we want.
  def matching_ocrx_words_for(hocr_nokogiri)
    hocr_nokogiri.search("//*[@class=\"ocrx_word\"]").select do |ocrx_word|
      @query.any? { |token| ocrx_word.text =~ /\b#{token}/i }
    end
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

  # Take Tesseract-provided ocrx_word span with bbox (as nokogiri element), and convert
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

  # Find possibly relevant Work children that may match query -- we do some postgres
  # filtering, but may need some additional in-memory ruby filtering of identified
  # members to avoid false positives for our full spec.
  #
  # @return [Array<Kithe::Model>]
  def identified_members
    @identified_members ||= begin
      members = work.members.order(:position).includes(:leaf_representative).strict_loading

      members = members.where(published: true) unless show_unpublished

      # Add in conditions to filter on our query
      members = pg_sql_for_asset_hocr_matching_query(scope: members, query: @query)

      # don't actualy need this, if we include weird extras oh well they won't match
      # our conditions.
      # members.select do |member|
      #   member.leaf_representative &&
      #   member.leaf_representative.content_type&.start_with?("image/") &&
      #   member.leaf_representative.stored?
      # end
    end
  end

  # We have a list of words to query, in a work's members. Rather than pull back ALL
  # members and filter in memory, it is better performance to filter with an SQL
  # query to postgres first.
  #
  # BUT, this is a bit tricky for a few reasons:
  #
  # * Structure of our data, we need to reach into a JSON structure... that contains
  #   XML, which we want to match text in. Using postgres regex search to match
  #   only at beginning of words, as per our spec.
  #
  # * Child works! If we have a child work, we include it's leaf_reprentative
  #   in the viewer, and want to match any text in it. Which requires us to do
  #   a pretty confusing self-referential join to search both immediate asset
  #   children AND any leaf_representatives of work children.
  #
  # The search doesn't need to be perfect, it can include false positives that
  # are later filtered out in ruby, but if it can cut down on the number of
  # DB results, it can improve performance significantly.
  #
  # postgres regexp reference: https://www.postgresql.org/docs/15/functions-matching.html#FUNCTIONS-POSIX-REGEXP
  #
  # @param scope [ActiveRecord::Relation] the base ActiveRecord scope to add our conditions on to
  # @para query [Array<String>] Our query words
  #
  # @return [ActiveRecord::Relation] with our conditions added on
  def pg_sql_for_asset_hocr_matching_query(scope:, query:)
    # to  include  matches on a child work's main leaf representative, we need to do a pretty
    # crazy manual SQL join on the leaf_representatives self-referential relationship -- so
    # we can assign an SQL alias ourselves to refer to it.
    scope = scope.joins("LEFT OUTER JOIN kithe_models AS leaf_representatives ON leaf_representatives.id = kithe_models.leaf_representative_id")

    # For each clause in our query, we will see if it exists in the "hocr" data -- checking
    # both direct member, and a member's leaf representative, so we have TWO clauses that both
    # need a bound value.
    #
    # Note: ~* is pg case-insensitive regex match
    #
    # Note: This might create false positives matching on XML tags instead of just content,
    # We experimented with using postgres xml fucntions, but the performance was bad,
    # better performance to filter them out later in ruby.
    clause= "(kithe_models.derived_metadata_jsonb ->> 'hocr') ~* ? OR (leaf_representatives.derived_metadata_jsonb ->> 'hocr') ~* ?"

    # We repeat that clause once for every query token, joined with OR
    sql = query.length.times.collect do
      clause
    end.join(" OR ")

    # Now we need to supply params for each of those ? variables. We'll do it as
    # a pg regexp using the \m "beginning of word boundary token", so that we only
    # match on beginning of words.
    #
    # The source in the DB is XML, so we need to XML-escape word-internal single and
    # double quotes the same way tesseract does when creating the hocr
    params = query.collect { |token| token.gsub("'", "&#39;").gsub('"', "&quot;") }.
      collect { |token| "\\m#{token}" }

    # but now we have to DOUBLE the parameters, cause each clause had one ? for main table and one for leaf representatives
    params = params.collect { |re| [re, re] }.flatten

    scope.where(sql, *params)
  end

end
