require 'attr_json'
class OralHistoryContent
  class IntervieweeDate
    include AttrJson::Model
    CATEGORY_VALUES = %w{birth death}

    validates_format_of :date, with: /\A\d{4}(-\d{2}(-\d{2})?)?\z/,
      message: "must be of format YYYY[-MM-DD]"

    validates_presence_of :category

    validates :category, inclusion:
      { in: CATEGORY_VALUES,
        allow_blank: false,
        message: "%{value} is not a valid category. Choose birth or death." }

    # TODO validate `category` string can be either 'birth' or 'death'
    attr_json :date,  :string
    attr_json :place, :string
    attr_json :category,  :string

  end
end