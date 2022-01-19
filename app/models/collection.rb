# A collection thumbnail is stored as an Asset, which has the collection as it's parent (not any work),
# and is set as the collections #representative too.
#
# Since the member relation destroys children when parent is deleted, deleting a collection
# automatically deletes the thumb (which automatically deletes the stored file)
class Collection < Kithe::Collection

  include RecordPublishedAt

  # automatic Solr indexing on save
  if ScihistDigicoll::Env.lookup(:solr_indexing) == 'true'
    self.kithe_indexable_mapper = CollectionIndexer.new
  end

  validates :related_url, array_inclusion: {
    proc: ->(v) { ScihistDigicoll::Util.valid_url?(v) } ,
    message: "is not a valid url: %{rejected_values}"
  }

  accepts_nested_attributes_for :representative

  attr_json :description, :text
  attr_json :related_url, :string, array: true

  attr_json :department, :string
  validates :department, presence: {}, inclusion: { in: Work::ControlledLists::DEPARTMENT, allow_blank: true }

  attr_json :funding_credit, FundingCredit.to_type

  # Override the default ActiveRecord one to create a new Asset if it didn't exist already.
  # The default AR didn't work quite right because of STI and other reasons, but this works
  # nicely, if representative_attributes come form form and a representative doesn't exist
  # already, it'll create one, with this collection as a parent, and set to this collection's
  # representative -- that'll all be automatically saved iff the collection is succesfully saved.
  #
  # If there already was a representative, still works.
  #
  # We also set the asset title to the file title, if appropriate.
  def representative_attributes=(attributes)
    if representative.nil?
      build_representative
    end
    self.representative.assign_attributes(attributes)

    if filename = representative.file&.try(:metadata).try(:[], :filename)
      representative.title = filename
    end
  end

  def build_representative
    self.representative = CollectionThumbAsset.new(title: "collection-thumbnail-placeholder", parent: self)
  end
end
