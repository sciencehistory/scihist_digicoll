require 'attr_json'
class OralHistoryContent
  class IntervieweeHonor
    include AttrJson::Model
    validates_format_of :date, with: /\A\d{4}(-\d{2}(-\d{2})?)?\z/,
      message: "must be of format YYYY[-MM-DD]"
    attr_json :date, :string
    attr_json :honor, :string

  end
end