class FetchMorePagesLinkComponent < ApplicationComponent
  def initialize(start_index:, images_per_page:, total_count:)
    @start_index = start_index
    @images_per_page = images_per_page
  end

  def call
    link_to("#", class:"lazy-member-images-link show-member-list-item", data: { trigger: "lazy-member-images", start_index: @start_index, images_per_page: @images_per_page }) do
      content_tag("span", "Fetch more works")
    end
  end
end
