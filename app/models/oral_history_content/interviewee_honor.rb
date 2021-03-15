class OralHistoryContent
  class IntervieweeHonor
    include AttrJson::Model
    validates_with StandardDateValidator, fields: [:date]

    attr_json :date, :string
    attr_json :honor, :string
  end
end
