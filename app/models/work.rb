

class Work < Kithe::Work
  # make sure only allowed format values in multi-value format attribute
  validates_each :format do |record, attr, value_arr|
    # for weird rails reasons, the empty string will be in there...
    unless (value_arr - Work::ControlledLists::FORMAT).empty?
      record.errors.add(attr, :inclusion)
    end
  end

  validates :department, inclusion: { in: ControlledLists::DEPARTMENT, allow_blank: true }
  validates :file_creator, inclusion: { in: ControlledLists::FILE_CREATOR, allow_blank: true }
  validates_presence_of :external_id

  #validate :genre

  attr_json :additional_title, :string, array: true
  attr_json :external_id, Work::ExternalId.to_type, array: true
  attr_json :creator, Work::Creator.to_type, array: true
  attr_json :date, Work::Date.to_type, array: true
  attr_json :place, Work::Place.to_type, array: true
  attr_json :format, :string, array: true
  attr_json :genre, :string, array: true
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
  attr_json :rights, :string, array: true
  attr_json :rights_holder, :string, array: true
  attr_json :additional_credit, Work::AdditionalCredit.to_type, array: true

  attr_json :file_creator, :string
  attr_json :admin_note, :text

  # filter out empty strings, makes our forms easier, with the way checkbox
  # groups include hidden field with empty string
  def format=(arr)
    if arr.is_a?(Array)
      arr = arr.reject {|v| v.blank? }
    end
    super(arr)
  end

end
