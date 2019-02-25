# module Importers
class CollectionAuditor < Auditor
  # Checks specific to the imported class.
  def special_checks()

    if metadata['child_ids'].nil?
      confirm(item.members == [], "members")
    else
      confirm(item.members.pluck(:friendlier_id) == metadata['child_ids'], "members")
    end

    v = metadata['description']
    if v.nil? || v == []
      confirm(item.description.nil?, "stray description")
    else
      confirm(item.description == v.first, 'description')
    end

    v = metadata['related_url']
    if v.nil? || v == []
      confirm(item.related_url.nil?, "stray related_url")
    else
      confirm(item.related_url == v, 'related_url')
    end
  end

  def self.exportee()
    return Collection
  end

  def self.importee()
    return 'Collection'
  end

  def self.destination_class()
    return Collection
  end
end # class
# end