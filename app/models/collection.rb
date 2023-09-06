# A collection thumbnail is stored as an Asset, which has the collection as it's parent (not any work),
# and is set as the collections #representative too.
#
# Since the member relation destroys children when parent is deleted, deleting a collection
# automatically deletes the thumb (which automatically deletes the stored file)
class Collection < Kithe::Collection
  include AttrJson::Record::QueryScopes

  include RecordPublishedAt

  # keep json_attributes out of string version of model shown in logs and console --
  # because it's huge, and mostly duplicated by individual attributes that will be included!
  self.filter_attributes = [:json_attributes]

  DEPARTMENT_EXHIBITION_VALUE = "Exhibition"
  DEPARTMENTS = (Work::ControlledLists::DEPARTMENT + [DEPARTMENT_EXHIBITION_VALUE]).freeze

  # automatic Solr indexing on save
  if ScihistDigicoll::Env.lookup(:solr_indexing) == 'true'
    self.kithe_indexable_mapper = CollectionIndexer.new
  end

  validates :related_url, array_inclusion: {
    proc: ->(v) { ScihistDigicoll::Util.valid_url?(v) } ,
    message: "is not a valid url: %{rejected_values}"
  }

  accepts_nested_attributes_for :representative

  attr_json :external_id, Work::ExternalId.to_type, array: true, default: -> { [] }

  attr_json :description, :text

  # legacy related_url to be replaced by related_link
  attr_json :related_url, :string, array: true
  attr_json :related_link, RelatedLink.to_type, array: true, default: -> { [] }

  attr_json :department, :string
  validates :department, presence: {}, inclusion: { in: DEPARTMENTS, allow_blank: true }

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

  # For ransack use, we need to list all attributes we want to use ransack to SEARCH or SORT by.
  #
  # We really probably oughta stop using ransack, I hate having this in the model.
  def self.ransackable_attributes(auth_obj=nil)
    ["title", "id", "created_at", "updated_at"]
  end
  # We don't use ransack with associations, but still have to include this method
  def self.ransackable_associations(auth_object = nil)
    []
  end
end
