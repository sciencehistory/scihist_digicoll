require 'attr_json'
class OralHistoryContent
  class IntervieweeDate
    include AttrJson::Model
    validates_format_of :date, with: /\A\d{4}(-\d{2}(-\d{2})?)?\z/,
      message: "must be of format YYYY[-MM-DD]"

    # TODO validate `type` string can be either 'birth' or 'death'
    attr_json :date,  :string
    attr_json :place, :string
    attr_json :type,  :string

  end
end