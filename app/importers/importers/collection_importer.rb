module Importers
class CollectionImporter < Importers::Importer

  def populate()
    super

    target_item.description = @metadata['description'].first

    if metadata["related_url"].present?
      target_item.related_url = metadata["related_url"]
    end

    if metadata['members'].present?
      member_ids = Kithe::Model.where(friendlier_id: metadata['members']).pluck(:id)
      if member_ids.count != metadata['members'].count
        add_error("some members may be missing, expected #{metadata['members'].count}, only found #{member_ids.count} to associate")
      end
      target_item.contain_ids = member_ids
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

  def create_or_update_thumbnail()
    return if metadata['representative_image_path'].nil?
    thumb = find_thumbnail() || CollectionThumbAsset.new()
    the_path = thumb_image_path()
    if thumb.file.nil? && !the_path.nil?
      thumb.file_attacher.set_promotion_directives(promote: "inline")
      thumb.file_attacher.set_promotion_directives(create_derivatives: "inline")
      thumb.file = File.open(the_path)
    end
    thumb.title = "Thumbnail for #{target_item.title}"
    thumb.parent = target_item
    thumb.save!
    target_item.representative = thumb
    target_item.leaf_representative = thumb
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
end
end
