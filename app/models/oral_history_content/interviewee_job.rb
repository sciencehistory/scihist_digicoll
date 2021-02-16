require 'attr_json'
class OralHistoryContent
  class IntervieweeJob
    include AttrJson::Model

    # We need a start date at least, so we can sort chronologically.
    validates_presence_of :start

    validates_presence_of :institution

    validates_format_of :start, with: /\A\d{4}(-\d{2}(-\d{2})?)?\z/,
      message: "must be of format YYYY[-MM-DD]"
    validates_format_of :end, with: /\A\d{4}(-\d{2}(-\d{2})?)?\z/,
      message: "must be of format YYYY[-MM-DD]"

    # oral_history_content.interviewee_job = [
    #   {start: 1962, end: 1965, institution: 'Harvard University',  role: 'Junior Fellow, Society of Fellows'},
    #   {start: 1965, end: 1968,  institution: 'Cornell University', role: 'Associate Professor, Chemistry'}
    # ]

    attr_json :start,       :string
    attr_json :end,         :string
    attr_json :institution, :string
    attr_json :role,        :string

  end
end