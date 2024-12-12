# Display the provenance of a work on the front end:
# WorkProvenanceComponent.new(work.provenance).display
class WorkPhysicalContainerComponent < ApplicationComponent
  attr_reader :work

  def initialize(work)
    @work = work
  end

  def render?
    true
  end
  
  private

  def public_contained_by
    @public_contained_by ||= @work.contained_by.where(published: true)
  end

  def box_id
    @work&.physical_container&.box
  end

  def folder_id
    @work&.physical_container&.folder
  end

  def link_to_box_and_folder
    collection = public_contained_by.first
    return nil if collection.nil? || box_id.nil?
    if folder_id.present? && folder_id&.chomp&.match(/^[\d]+$/)
      collection_path(collection_id = collection.friendlier_id, box_id:box_id, folder_id: folder_id, sort:'box_folder')
    else
      collection_path(collection_id = collection.friendlier_id, box_id:box_id, sort:'box_folder')
    end
  end

  def box_and_folder
    [
      (box_id.present? ? "Box #{box_id}" : nil),
      (folder_id.present? ? "Folder #{folder_id}" : nil),
    ].compact.join (", ")
  end

end
