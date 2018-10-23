class Work < Kithe::Work
  validate :test_validation_errors

  def test_validation_errors
    #errors.add(:external_id, "is wrong because we said so")
  end

  # No repeatable yet, getting there
  attr_json :additional_title, :string, array: true
  attr_json :external_id, Work::ExternalId.to_type, array: true
  attr_json :creator, Work::Creator.to_type
  attr_json :format, :string
  attr_json :genre, :string
  attr_json :medium, :string
  attr_json :extent, :string
  attr_json :language, :string
  attr_json :description, :text
  attr_json :inscription, Work::Inscription.to_type

  # eventually keep vocab id
  attr_json :subject, :string

  attr_json :department, :string
  attr_json :exhibition, :string
  attr_json :source, :string
  attr_json :series_arrangement, :string
  attr_json :physical_container, Work::PhysicalContainer.to_type

  # Turn into type of url and value please
  attr_json :related_url, :string
  attr_json :rights, :string
  attr_json :rights_holder, :string
  attr_json :additional_credit, :string

  attr_json :file_creator, :string
  attr_json :admin_note, :text

  attr_json_accepts_nested_attributes_for :external_id

end
