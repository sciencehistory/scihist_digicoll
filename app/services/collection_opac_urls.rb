# Calculate OPAC urls from external_ids for a collection, no big deal
class CollectionOpacUrls
  attr_reader :collection

  def initialize(collection)
    @collection = collection
  end

  # from our external_id with bib IDs in it.
  def opac_urls
    @opac_urls ||= begin
      # bib_ids are supposed to be `b` followed by 7 numbers, but sometimes
      # extra digits get in, cause Siera staff UI wants to add em, but
      # they won't work for links to OPAC, phew.
      bib_ids = (collection.external_id || []).find_all do |external_id|
        external_id.category == "bib"
      end.map(&:value).map { |id| id.slice(0,8) }

      bib_ids.collect(&:downcase).uniq.map do |bib_id|
        ScihistDigicoll::Util.opac_url(bib_id)
      end
    end
    @opac_urls
  end

end
