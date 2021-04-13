class OralHistoryContent
  class IntervieweeBiography
    include AttrJson::Model

    attr_json :name, :string

    attr_json :birth,  OralHistoryContent::DateAndPlace.to_type, default: -> { OralHistoryContent::DateAndPlace.new }
    attr_json :death,  OralHistoryContent::DateAndPlace.to_type, default: -> { OralHistoryContent::DateAndPlace.new }

    attr_json :school,  OralHistoryContent::IntervieweeSchool.to_type, array: true, default: -> {[]}
    attr_json :job,     OralHistoryContent::IntervieweeJob.to_type,    array: true, default: -> {[]}
    attr_json :honor,   OralHistoryContent::IntervieweeHonor.to_type,  array: true, default: -> {[]}

    validates_presence_of :name
  end
end
