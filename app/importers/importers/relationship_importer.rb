# We take work import metadata, and set all relationships mentioned in it.
# We need to do this as a seperate step, because all the works and assets
# have to exist in order to set their relationships.
#
# Thus, these must be run after the Asset and GenericWork importers have run on
# all import files.
class Importers::RelationshipImporter
  attr_reader :work_metadata
  def initialize(work_metadata)
    @work_metadata = work_metadata
  end

  def friendlier_id
    work_metadata["id"]
  end

  def import
    child_ids = work_metadata['child_ids'] || []
    rep_fid = work_metadata['representative_id']
    parent_id = friendlier_id

    # Possible refactor:
    # parent.contains = Kithe::Model.where(friendlier_id: child_ids)
    # parent.representative_id = @@representative_hash[parent.friendlier_id]
    # parent.save!

    parent = Work.find_by_friendlier_id!(parent_id)
    current_position = 0
    child_ids.each do |child_id|
      # This child could be a Work *or* an Asset, so look it up this way:
      child = Kithe::Model.find_by_friendlier_id(child_id)
      # In theory, once you get to this point in the ingest, all the possible
      # Assets and child Works have already been ingested. But just to be sure...
      if child.nil?
        raise TypeError.new("ERROR: GenericWork  #{parent_id}: has nil child item.")
      end

      #Link the child and its parent.
      child.parent_id = parent.id
      child.position = (current_position += 1)
      child.save!

      # Set the representative.
      # TODO: This would break if the representative happens to not be
      # not the child of this item, which could in theory be the case.
      if child.friendlier_id == rep_fid
        parent.representative_id = child.id
        parent.save!
      end
    end
  end
end
