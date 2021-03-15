class OralHistoryContent
  class IntervieweeSchool
    include AttrJson::Model
    validates_with StandardDateValidator, fields: [:date]
    attr_json :date,        :string
    attr_json :institution, :string
    attr_json :degree,      :string
    attr_json :discipline,  :string
  end
end
