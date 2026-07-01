# just displays the "100 items, 96 public" message, appropriate for whether
# user can see the non-public ones
class CollectionCountComponent < ApplicationComponent
  delegate :can_see_unpublished_records?, to: :helpers

  attr_reader :collection

  def initialize(collection)
    @collection = collection
  end

  def public_work_count
    @public_work_count ||= collection.contains.where(published: true).count
  end

  def all_work_count
    @all_work_count ||= collection.contains.count
  end

  def public_asset_count
    @public_asset_count ||= collection.contains.where(published: true).count
  end

  def all_asset_count
    @all_asset_count ||= all_descendent_members
  end


  def all_descendent_members
    raise TypeError.new("can only call on a persisted object") unless collection.persisted? && collection.id.present?

    sql = <<~EOS
      id IN (WITH RECURSIVE tree AS (
        SELECT id, ARRAY[]::UUID[] AS ancestors
        FROM kithe_models WHERE id = '#{collection.id}'

        UNION ALL

        SELECT kithe_models.id, tree.ancestors || kithe_models.parent_id
        FROM kithe_models, tree
        WHERE kithe_models.parent_id = tree.id
      ) SELECT count(id) FROM tree WHERE id != '#{collection.id}')
    EOS
    #byebug


    Kithe::Model.where(sql)
  end

end
