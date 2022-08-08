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

  # from related_url (legacy), or from our external_id with bib IDs in it.
  def opac_urls
    @opac_urls ||= begin
      # bib_ids are supposed to be `b` followed by 7 numbers, but sometimes
      # extra digits get in, cause Siera staff UI wants to add em, but
      # they won't work for links to OPAC, phew.
      bib_ids = (collection.external_id || []).find_all do |external_id|
        external_id.category == "bib"
      end.map(&:value).map { |id| id.slice(0,8) }

      (bib_ids.collect(&:downcase) + related_url_filter.opac_ids.collect(&:downcase)).uniq.map do |bib_id|
        ScihistDigicoll::Util.opac_url(bib_id)
      end
    end
    @opac_urls
  end

  def related_urls
    related_url_filter.filtered_related_urls
  end

  private

  def related_url_filter
    @related_url_filter ||= RelatedUrlFilter.new(collection.related_url)
  end
end
