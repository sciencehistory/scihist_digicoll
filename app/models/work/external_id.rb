class Work::ExternalId
  TYPE_VOCAB = %w{object_id sierra_bib_num sierra_item_num accession_num aspace_reference_num oral_history_interview_num}

  include AttrJson::Model

  attr_json :type, :string
  attr_json :value, :string
end
