class Work < Kithe::Work
  # will trigger automatic solr indexing in callbacks
  self.kithe_indexable_mapper = WorkIndexer.new


  belongs_to :digitization_queue_item, optional: true, class_name: "Admin::DigitizationQueueItem"

  has_many :on_demand_derivatives, inverse_of: :work, dependent: :destroy

  has_many :cart_items, dependent: :delete_all

  validates :external_id, presence: true
  validates :department, inclusion: { in: ControlledLists::DEPARTMENT, allow_blank: true }
  validates :file_creator, inclusion: { in: ControlledLists::FILE_CREATOR, allow_blank: true }
  validates :rights, inclusion: { in: RightsTerms.all_ids, allow_blank: true }
  validates :format, array_inclusion: { in: ControlledLists::FORMAT }
  validates :genre, array_inclusion: { in: ControlledLists::GENRE  }
  validates :exhibition, array_inclusion: { in: ControlledLists::EXHIBITION  }
  validates :project, array_inclusion: { in: ControlledLists::PROJECT  }
  validates :related_url, array_inclusion: {
    proc: ->(v) { ScihistDigicoll::Util.valid_url?(v) } ,
    message: "is not a valid url: %{rejected_values}"
  }

  with_options if: :published?, message: "can't be blank for published works" do |work|
    work.validates_presence_of :date_of_work
    work.validates_presence_of :format
    work.validates_presence_of :genre
    work.validates_presence_of :department
    work.validates_presence_of :rights
  end


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
  attr_json :provenance, :text
  attr_json :inscription, Work::Inscription.to_type, array: true, default: -> { [] }

  # eventually keep vocab id?
  attr_json :subject, :string, array: true, default: -> { [] }

  attr_json :department, :string
  attr_json :exhibition, :string, array: true, default: -> { [] }
  attr_json :project, :string, array: true, default: -> { [] }
  attr_json :source, :string
  attr_json :series_arrangement, :string, array: true, default: -> { [] }
  attr_json :physical_container, Work::PhysicalContainer.to_type

  # Turn into type of url and value?
  attr_json :related_url, :string, array: true, default: -> { [] }
  attr_json :rights, :string
  attr_json :rights_holder, :string
  attr_json :additional_credit, Work::AdditionalCredit.to_type, array: true, default: -> { [] }
  attr_json :digitization_funder, :string

  attr_json :file_creator, :string
  attr_json :admin_note, :text, array: true, default: -> { [] }

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

  # This method is used by `oai` gem to automatically get serialization for oai-pmh responses
  # @returns [String] XML, note as a STRING.
  def to_oai_dc
    WorkOaiDcSerialization.new(self).to_oai_dc
  end

  # @returns [Array] of IANA/MIME content types from any members.
  #
  # It will collect these by visiting each actual member, and then uniquing. Results are then
  # _cached_, so subsequent calls will _not_ reflect any changes you've made to members or
  # their content types -- unless you pass in `reset:false`.
  #
  # The Work model is a kind of architectural unfortunate place to put this, but it worked
  # for being easily accessible from the DownloadDropdownDisplay, which is what this method
  # is intended for. Multiple DownloadDropdownDisplays needed to get this value for the same
  # work without re-calculating it. See https://github.com/sciencehistory/scihist_digicoll/pull/334
  #
  # Note that for this to be most performant, you have to have members => leaf_representatives
  # eager-loaded, so it doesn't lead to an n+1 problem.
  def member_content_types(reset: false)
    @member_content_types = nil if reset
    @member_content_types ||= begin
      warned = false

      members.collect do |member|
        unless warned || member.association(:leaf_representative).loaded?
          Rails.logger.warn("Calling Work#member_content_types without pre-loading members => leaf_representative may be dangerous to performance")
          warned = true
        end

        member.leaf_representative&.content_type
      end.compact.uniq
    end
  end

  # @returns [Integer] count of members (cached)
  #
  # This will keep returning the same number in subsequent times called on the same instance, it's cached.
  #
  # It's really only meant for use in display code, and specifically created for DownloadDropdownDisplay.
  #
  # This is architecturally not a great place to put this, but it works. See also #member_content_types
  def member_count(reset: false)
    @member_count = nil if reset
    @member_count ||= members.size
  end

end
