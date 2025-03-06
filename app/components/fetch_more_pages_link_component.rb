class FetchMorePagesLinkComponent < ApplicationComponent
  def initialize(start_index:, images_per_page:)
    @start_index = start_index
    @images_per_page = images_per_page
  end

  def call
    link_to("Fetch more works", "", class:"lazy-member-images-link", data: { trigger: "lazy-member-images", start_index: @start_index, images_per_page: @images_per_page })
  end
end
