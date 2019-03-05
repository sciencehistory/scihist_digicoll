

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


  attr_json :additional_title, :string, array: true, default: -> { [] }
  attr_json :external_id, Work::ExternalId.to_type, array: true, default: -> { [] }
  attr_json :creator, Work::Creator.to_type, array: true, default: -> { [] }
  attr_json :date_of_work, Work::DateOfWork.to_type, array: true, default: -> { [] }
  attr_json :place, Work::Place.to_type, array: true, default: -> { [] }
  attr_json :format, :string, array: true, default: -> { [] }
  attr_json :genre, :string, array: true, default: -> { [] }
  attr_json :medium, :string, array: true, default: -> { [] }
  attr_json :extent, :string, array: true, default: -> { [] }
  attr_json :language, :string, array: true, default: -> { [] }
  attr_json :description, :text
  attr_json :inscription, Work::Inscription.to_type, array: true, default: -> { [] }

  # eventually keep vocab id?
  attr_json :subject, :string, array: true, default: -> { [] }

  attr_json :department, :string
  attr_json :exhibition, :string, array: true, default: -> { [] }
  attr_json :source, :string
  attr_json :series_arrangement, :string, array: true, default: -> { [] }
  attr_json :physical_container, Work::PhysicalContainer.to_type

  # Turn into type of url and value?
  attr_json :related_url, :string, array: true, default: -> { [] }
  attr_json :rights, :string
  attr_json :rights_holder, :string
  attr_json :additional_credit, Work::AdditionalCredit.to_type, array: true, default: -> { [] }

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

  # With one pg recursive CTE find _all_ descendent members, through
  # multiple levels.
  #
  # TODO: Move to kithe? Make more general, a class method that takes
  # IDs?
  def all_descendent_members
    raise TypeError.new("can only call on a persisted object") unless persisted? && id.present?

    sql = <<~EOS
      id IN (WITH RECURSIVE tree AS (
        SELECT id, ARRAY[]::UUID[] AS ancestors
        FROM kithe_models WHERE id = '#{self.id}'

        UNION ALL

        SELECT kithe_models.id, tree.ancestors || kithe_models.parent_id
        FROM kithe_models, tree
        WHERE kithe_models.parent_id = tree.id
      ) SELECT id FROM tree WHERE id != '#{self.id}')
    EOS


    Kithe::Model.where(sql)
  end

end
