# A standard draper decorator, but we name it Collection SHOW decorator specifically,
# it's the 'helper' methods we need for collection show page.
#
# So you can't use draper .decorate to automatically find it, instead just do:
#
#     CollectionShowDecorator.new(collection)
class CollectionShowDecorator < Draper::Decorator
  delegate_all

  def public_count
    @public_count ||= model.contains.where(published: true).count
  end

  def all_count
    @all_count ||= model.contains.count
  end

  def opac_urls
    related_url_filter.opac_urls
  end

  def related_urls
    related_url_filter.filtered_related_urls
  end

  private

  def related_url_filter
    @related_url_filter ||= RelatedUrlFilter.new(model.related_url)
  end
end
