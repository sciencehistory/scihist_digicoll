class CollectionImporter < Importer
  def edit_hash(h)
    h['members'] = members
    h
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

  def post_processing()
    update_collection_members()
  end

  def update_collection_members()
    return if metadata['members'].nil?
    metadata['members'].each do | work_id |
      member = Work.find_by_friendlier_id(work_id)
      if member.nil?
        raise RuntimeError.new("Couldn't find Work #{work_id} that is supposed to be in collection #{new_item.friendlier_id}.")
      end
      new_item.contains << member
      new_item.save!
      member.save!
    end
  end

  def how_long_to_sleep()
    0
  end

end
