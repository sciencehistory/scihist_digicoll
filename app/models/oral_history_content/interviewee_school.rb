require 'attr_json'
class OralHistoryContent
  class IntervieweeSchool
    include AttrJson::Model
    validates_format_of :date, with: /\A\d{4}(-\d{2}(-\d{2})?)?\z/,
      message: "must be of format YYYY[-MM-DD]"

    validates_presence_of :date

    validates_presence_of :institution

    attr_json :date,        :string
    attr_json :institution, :string
    attr_json :degree,      :string
    attr_json :discipline,  :string
  end
end