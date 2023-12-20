# See e.g.
# https://ia800900.us.archive.org/fulltext/inside.php?item_id=theworksofplato01platiala&doc=theworksofplato01platiala&path=/25/items/theworksofplato01platiala&q=person&pre_tag=%7B%7B%7B&post_tag=%7D%7D%7D&callback=jQuery36107291250223163721_1703011056741
# for a sample response...
class BookviewerSearchSerializer
  include Rails.application.routes.url_helpers

  attr_reader :work, :show_unpublished

  def initialize(work, show_unpublished: false, query: "")
    @work = work
    @show_unpublished = show_unpublished
    @query = query.downcase
  end

  def matches
    result = []
    work.members.each do |member|
      page_number = member.position # TODO don't assume "page" is the same as m.position
      next unless member.hocr
      parsed_hocr = Nokogiri::XML(member.hocr) { |config| config.strict }
      next unless parsed_hocr.css(".ocr_page").length == 1

      words_on_this_page = parsed_hocr.search('//*[@class="ocrx_word"]')
      
      matches_on_this_page = words_on_this_page.
        select {|w| w.text().downcase.include? @query }
      
      matches_on_this_page.each do |match|
        coordinates = extract_coordinates(match.attributes['title'].value)
        extra_margin = 30
        result << {
              "text": extract_context(match),
              "par": [
                  {
                      "l":coordinates[:left] - extra_margin,
                      "t":coordinates[:top] - extra_margin,
                      "r":coordinates[:right] + extra_margin,
                      "b":coordinates[:bottom] + extra_margin,
                      "page": page_number - 1,
                      "boxes": [
                          {
                              "l":coordinates[:left] - extra_margin,
                              "t":coordinates[:top] - extra_margin,
                              "r":coordinates[:right] + extra_margin,
                              "b":coordinates[:bottom]  + extra_margin,
                              "page": page_number - 1,
                          },
                          # {
                          #     "l": 1025,
                          #     "t": 524,
                          #     "r": 1178,
                          #     "b": 560,
                          #     "page": 3
                          # }
                      ],
                      "page_width": member.width,
                      "page_height": member.height
                  }
              ]
          }
      end
    end
    result
  end

  def extract_context(match)
    match_id = match.attributes["id"].value
    match.parent.xpath('*[@class="ocrx_word"]').map do |word|
      (word['id'] == match_id) ? "{{{#{word.text}}}}" : word.text
    end.join(' ')
  end

  def extract_coordinates(coords)
    #https://en.wikipedia.org/wiki/HOCR#bbox
    #"bbox 1299 1809 1402 1837; x_wconf 91"
    if /bbox (\d*) (\d*) (\d*) (\d*)\; x_wconf (\d*)/ =~ coords
      return {
        left:    $1.to_i,
        top:     $2.to_i,
        right:   $3.to_i,
        bottom:  $4.to_i,
        x_wconf: $5.to_i
      }
    end
  end

  def as_hash
    {
        ia: @work.friendlier_id,
        q: @query,
        indexed: true,
        matches: matches
    }
  end

  private

  # TODO handle child works.
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
