class CollectionAuditor < Auditor

  # Checks specific to the imported class.
  def special_checks()
    confirm(item.members.pluck(:friendlier_id) == metadata['child_ids'], "members")
  end

  def populate()
    super
    %w(description related_url).each do |k|
      v = metadata[k]
      next if v.nil? || v == []
      new_item.send("#{k}=", v)
    end
  end

  def members()
    target_item.members.map(&:id)
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

  def check_collection_members()
    return if metadata['members'].nil?
    metadata['members'].each do | work_id |
      member = Work.find_by_friendlier_id(work_id)
      if member.nil?
        puts "ERROR: collection #{new_item.friendlier_id} refers to nonexistent member #{work_id}"
        next
      end # if member not found.
      # check that the member does indeed have this item in its contained_by list.
    end # each
  end # method

end # class