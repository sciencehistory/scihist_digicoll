module Import
class Import::CollectionImporter < Import::Importer

  def edit_metadata()
    @metadata['description'] = @metadata['description'].first unless @metadata['description'].nil?
  end

  def populate()
    super
    %w(description related_url).each do |k|
      v = metadata[k]
      next if v.nil? || v == []
      new_item.send("#{k}=", v)
    end
    create_or_update_thumbnail()
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
  
  def create_or_update_thumbnail()
    return if metadata['representative_image_path'].nil?
    thumb = find_thumbnail() || CollectionThumbAsset.new()
    the_path = thumb_image_path()
    if thumb.file.nil? && !the_path.nil?
      thumb.file_attacher.set_promotion_directives(promote: "inline")
      thumb.file_attacher.set_promotion_directives(create_derivatives: "inline")
      thumb.file = File.open(the_path)
    end
    thumb.title = "Thumbnail for #{new_item.title}"
    thumb.parent = new_item
    thumb.save!
    new_item.representative = thumb
    new_item.leaf_representative = thumb
  end

  def find_thumbnail()
    return nil if metadata['representative_image_path'].nil?
    CollectionThumbAsset.find do  |x|
      !x.file.nil? &&
      x.file.metadata['filename'] == metadata['representative_image_path']
    end
  end

  def thumb_image_path()
    return nil if metadata['representative_image_path'].nil?
    return nil if metadata['representative_image_path'] == ""
    path = Rails.root.join('tmp', 'collection_thumb_paths', metadata['representative_image_path'])
    return nil unless  File.exists? path
    path.to_s
  end
  
  def update_collection_members()
    return if metadata['members'].nil?
    
    # Possible refactor:
    # new_item.contain_ids = Kithe::Model.where(friendlier_id: metadata['members']).pluck(:id)
    # new_item.save!

    metadata['members'].each do | work_id |
      member = Work.find_by_friendlier_id(work_id)
      if member.nil?
        report_via_progress_bar("ERROR: refers to nonexistent member #{work_id}")
        next
      end
      new_item.contains << member
      new_item.save!
      # TODO we haven't actually done anything to member
      # so probably no need to save it.
      member.save!
    end
  end

end
end
