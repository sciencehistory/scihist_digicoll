class Work::ExternalId
  CATEGORY_VALUES = %w{object_id sierra_bib_num sierra_item_num accession_num aspace_reference_num oral_history_interview_num}

  include AttrJson::Model

  validates_presence_of :category, :value
  validates :category, inclusion:
    { in: CATEGORY_VALUES,
      allow_blank: true,
      message: "%{value} is not a valid category" }

  attr_json :category, :string
  attr_json :value, :string
end
