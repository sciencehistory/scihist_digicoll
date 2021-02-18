require 'attr_json'
class OralHistoryContent
  class IntervieweeBirth
    include AttrJson::Model

    validates_format_of :date, with: /\A\d{4}(-\d{2}(-\d{2})?)?\z/,
      message: "must be of format YYYY[-MM-DD]"

    # TODO validate `category` string can be either 'birth' or 'death'
    attr_json :date,  :string
    attr_json :city, :string
    attr_json :state, :string
    attr_json :province, :string
    attr_json :country, :string

  end
end