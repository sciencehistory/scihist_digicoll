# A little section wtih some brief description of the collection, on a collection
# show page.
class CollectionMetadataComponent < ApplicationComponent
  delegate :current_staff_user?, to: :helpers

  attr_reader :collection, :show_links

  def initialize(collection:, show_links: true)
    @collection = collection
    @show_links = show_links
  end

  def public_count
    @public_count ||= collection.contains.where(published: true).count
  end

  def all_count
    @all_count ||= collection.contains.count
  end

  def opac_urls
    related_url_filter.opac_urls
  end

  def related_urls
    related_url_filter.filtered_related_urls
  end

  private

  def related_url_filter
    @related_url_filter ||= RelatedUrlFilter.new(collection.related_url)
  end
end
