class OralHistoryContent
  class IntervieweeHonor
    include AttrJson::Model
    validates_with StandardDateValidator, fields: [:date]
    validates_presence_of :honor
    attr_json :date, :string
    attr_json :honor, :string

  end
end