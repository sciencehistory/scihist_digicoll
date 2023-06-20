# just displays the "100 items, 96 public" message, appropriate for whether
# user can see the non-public ones
class CollectionCountComponent < ApplicationComponent
  delegate :can_see_unpublished_records?, to: :helpers

  attr_reader :collection

  def initialize(collection)
    @collection = collection
  end

  def public_count
    @public_count ||= collection.contains.where(published: true).count
  end

  def all_count
    @all_count ||= collection.contains.count
  end
end
