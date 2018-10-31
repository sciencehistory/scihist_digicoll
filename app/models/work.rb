

class Work < Kithe::Work
  validates :external_id, presence: true
  validates :department, inclusion: { in: ControlledLists::DEPARTMENT, allow_blank: true }
  validates :file_creator, inclusion: { in: ControlledLists::FILE_CREATOR, allow_blank: true }
  validates :rights, inclusion: { in: RightsTerms.all_ids, allow_blank: true }
  validates :format, array_inclusion: { in: ControlledLists::FORMAT }
  validates :genre, array_inclusion: { in: ControlledLists::GENRE  }
  validates :exhibition, array_inclusion: { in: ControlledLists::EXHIBITION  }
  validates :related_url, array_inclusion: {
    proc: ->(v) { ScihistDigicoll::Util.valid_url?(v) } ,
    message: "is not a valid url: %{rejected_values}"
  }


  attr_json :additional_title, :string, array: true
  attr_json :external_id, Work::ExternalId.to_type, array: true
  attr_json :creator, Work::Creator.to_type, array: true
  attr_json :date_of_work, Work::DateOfWork.to_type, array: true
  attr_json :place, Work::Place.to_type, array: true
  attr_json :format, :string, array: true
  attr_json :genre, :string, array: true
  attr_json :medium, :string, array: true
  attr_json :extent, :string, array: true
  attr_json :language, :string, array: true
  attr_json :description, :text
  attr_json :inscription, Work::Inscription.to_type, array: true

  # eventually keep vocab id?
  attr_json :subject, :string, array: true

  attr_json :department, :string
  attr_json :exhibition, :string, array: true
  attr_json :source, :string
  attr_json :series_arrangement, :string, array: true
  attr_json :physical_container, Work::PhysicalContainer.to_type

  # Turn into type of url and value?
  attr_json :related_url, :string, array: true
  attr_json :rights, :string
  attr_json :rights_holder, :string
  attr_json :additional_credit, Work::AdditionalCredit.to_type, array: true

  attr_json :file_creator, :string
  attr_json :admin_note, :text

  # filter out empty strings, makes our forms easier, with the way checkbox
  # groups include hidden field with empty string. Kithe repeatable
  # input normally handles this for us, but we're not using one for this one.
  def format=(arr)
    if arr.is_a?(Array)
      arr = arr.reject {|v| v.blank? }
    end
    super(arr)
  end

end
