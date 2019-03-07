# We take work import metadata, and set all relationships mentioned in it.
# We need to do this as a seperate step, because all the works and assets
# have to exist in order to set their relationships.
#
# Thus, these must be run after the Asset and GenericWork importers have run on
# all import files.
class Importers::RelationshipImporter
  attr_reader :work_metadata, :errors
  def initialize(work_metadata)
    @work_metadata = work_metadata
    @errors = []
  end

  def friendlier_id
    work_metadata["id"]
  end

  def add_error(str)
    @errors << str
  end

  # After running, check #errors for errors that you may want to output.
  def import
    Importers::Importer.without_auto_timestamps do
      parent = Work.find_by_friendlier_id(friendlier_id)

      if parent.nil?
        add_error("Could not find work #{friendlier_id} to import relationships")
        return false
      end

      (work_metadata['child_ids'] || []).each_with_index do |child_id, current_position|
        # This child could be a Work *or* an Asset, so look it up this way:
        child = Kithe::Model.find_by_friendlier_id(child_id)
        # In theory, once you get to this point in the ingest, all the possible
        # Assets and child Works have already been ingested. But just to be sure...
        if child.nil?
          add_error("ERROR: GenericWork #{parent.id}: couldn't find child #{child_id} to set membership")
        end

        #Link the child and its parent.
        child.parent_id = parent.id
        child.position = current_position
        child.save!
      end

      if work_metadata['representative_id'].present?
        parent.representative_id = Kithe::Model.find_by_friendlier_id!(work_metadata['representative_id']).id
        parent.save!
      end
    end
  end
end
