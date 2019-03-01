module Import
class Import::CollectionAuditor < Import::Auditor
  # Checks specific to the imported class.
  def special_checks()

    if metadata['members'].nil?
      confirm(item.contains == [], "members should be empty")
    else
      confirm(item.contains.pluck(:friendlier_id) == metadata['members'], "members")
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
end
