class OralHistoryContent
  class IntervieweeJob
    include AttrJson::Model
    validates_presence_of :institution
    validates_presence_of :start
    validates_with StandardDateValidator, fields: [:start, :end]
    attr_json :start,       :string
    attr_json :end,         :string
    attr_json :institution, :string
    attr_json :role,        :string
  end
end