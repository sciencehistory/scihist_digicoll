class OralHistoryContent
  class IntervieweeJob
    include AttrJson::Model
    validates_with StandardDateValidator, fields: [:start, :end]
    attr_json :start,       :string # date as yyyy(-mm(-dd))
    attr_json :end,         :string # date as yyyy(-mm(-dd))
    attr_json :institution, :string
    attr_json :role,        :string
  end
end
