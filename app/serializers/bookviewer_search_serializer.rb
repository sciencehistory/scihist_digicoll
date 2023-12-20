# See e.g.
# https://ia800900.us.archive.org/fulltext/inside.php?item_id=theworksofplato01platiala&doc=theworksofplato01platiala&path=/25/items/theworksofplato01platiala&q=person&pre_tag=%7B%7B%7B&post_tag=%7D%7D%7D&callback=jQuery36107291250223163721_1703011056741
# for a sample response...
class BookviewerSearchSerializer
  include Rails.application.routes.url_helpers

  THUMB_DERIVATIVE = :thumb_mini

  attr_reader :work, :show_unpublished

  def initialize(work, show_unpublished: false)
    @work = work
    @show_unpublished = show_unpublished
  end

  def as_hash
    {
        "ia": "theworksofplato01platiala",
        "q": "person",
        "indexed": true,
        "matches": [ 
          {
              "text": """wise  man  here,  a  Parian,  who  I  hear  is  staying  in  the  city. 
              For I  happened  to  visit  a  {{{person}}}  who  spends  more  money  on  the sophists 
              than  all  others  together,  I  mean  Callias,  son  of  Hip- ponicus.""",
              "par": [
                  {
                      "l": 576,
                      "t": 316,
                      "r": 1178,
                      "b": 560,
                      "page": 3,
                      "boxes": [
                          {
                              "l": 576,
                              "t": 316,
                              "r": 729,
                              "b": 352,
                              "page": 18
                          },
                          {
                              "l": 1025,
                              "t": 524,
                              "r": 1178,
                              "b": 560,
                              "page": 18
                          }
                      ],
                      "page_width": 1506,
                      "page_height": 2638
                  }
              ]
          }
      ]
  }
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

  # def download_options(asset)
  #   # include the PDF link here if we only have one image, as there won't be a
  #   # fixed whole-work download section, but we still want it.
  #   DownloadOptions::ImageDownloadOptions.new(asset, show_pdf_link: work.member_count == 1).options
  # end

  def thumb_src_attributes(asset)
    derivative_1x_url = asset.file_url(THUMB_DERIVATIVE)
    #derivative_2x_url = asset.file_url("#{THUMB_DERIVATIVE.to_s}_2X")
    {
      thumbSrc: derivative_1x_url,
      #thumbSrcset: "#{derivative_1x_url} 1x, #{derivative_2x_url} 2x"
    }
  end


end
