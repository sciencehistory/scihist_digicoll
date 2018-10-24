

class Work < Kithe::Work
  FORMAT_VALUES = %w{ image mixed_material moving_image physical_object sound text }
  # BUG, format is getting empty string. :(
  # make sure only allowed format values in multi-value format attribute
  # validates_each :format do |record, attr, value|
  #   # for weird rails reasons, the empty string will be in there...
  #   unless value.blank? || (FORMAT_VALUES - value).empty?
  #     record.errors.add(attr, :inclusion)
  #   end
  # end
  #
  GENRE_VALUES = [
      'Advertisements',
      'Artifacts',
      'Business correspondence',
      'Catalogs',
      'Charts, diagrams, etc',
      'Chemistry sets',
      'Clothing & dress',
      'Documents',
      'Drawings',
      'Encyclopedias and dictionaries',
      'Electronics',
      'Engravings',
      'Ephemera',
      'Etchings',
      'Glassware',
      'Handbooks and manuals',
      'Illustrations',
      'Implements, utensils, etc.',
      'Lithographs',
      'Manuscripts',
      'Medical equipment & supplies',
      'Minutes (Records)',
      'Molecular models',
      'Negatives',
      'Oral histories',
      'Paintings',
      'Pamphlets',
      'Personal correspondence',
      'Pesticides',
      'Photographs',
      'Plastics',
      'Portraits',
      'Postage stamps',
      'Press releases',
      'Prints',
      'Publications',
      'Rare books',
      'Sample books',
      'Scientific apparatus and instruments',
      'Slides',
      'Stereographs',
      'Textiles',
      'Vessels (Containers)',
      'Woodcuts'
    ]
  # we're not using key/value i18n, should we?
  validates :genre, inclusion: { in: GENRE_VALUES, allow_blank: true }

  DEPARTMENT_VALUES = [
    'Archives',
    'Center for Oral History',
    'Museum',
    'Library',
  ]
  validates :department, inclusion: { in: DEPARTMENT_VALUES, allow_blank: true }


  # No repeatable yet, getting there
  attr_json :additional_title, :string, array: true
  attr_json :external_id, Work::ExternalId.to_type, array: true
  attr_json :creator, Work::Creator.to_type, array: true
  attr_json :date, Work::Date.to_type, array: true
  attr_json :place, Work::Place.to_type, array: true
  attr_json :format, :string, array: true
  attr_json :genre, :string
  attr_json :medium, :string, array: true
  attr_json :extent, :string, array: true
  attr_json :language, :string, array: true
  attr_json :description, :text
  attr_json :inscription, Work::Inscription.to_type, array: true

  # eventually keep vocab id
  attr_json :subject, :string, array: true

  attr_json :department, :string
  attr_json :exhibition, :string, array: true
  attr_json :source, :string
  attr_json :series_arrangement, :string, array: true
  attr_json :physical_container, Work::PhysicalContainer.to_type

  # Turn into type of url and value please
  attr_json :related_url, :string, array: true
  attr_json :rights, :string
  attr_json :rights_holder, :string
  attr_json :additional_credit, :string

  attr_json :file_creator, :string
  attr_json :admin_note, :text

  attr_json_accepts_nested_attributes_for :external_id, :date, :creator, :place, :inscription, reject_if: :all_blank

end
