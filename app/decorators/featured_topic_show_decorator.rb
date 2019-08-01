# Helper methods methods we need for featured collection show page.
#
#
class FeaturedTopicShowDecorator < Draper::Decorator
  delegate_all

  # def public_count
  #   @public_count ||= model.contains.where(published: true).count
  # end

  # def all_count
  #   @all_count ||= model.contains.count
  # end

  # def opac_urls
  #   related_url_filter.opac_urls
  # end

  # def related_urls
  #   related_url_filter.filtered_related_urls
  # end

  # private

  # def related_url_filter
  #   @related_url_filter ||= RelatedUrlFilter.new(model.related_url)
  # end
end
