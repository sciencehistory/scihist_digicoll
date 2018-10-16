class Work < Kithe::Work
  # No repeatable yet, getting there
  attr_json :addtional_title, :string
  attr_json :external_id, Work::ExternalId.to_type
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

end
