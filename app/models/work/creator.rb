class Work::Creator
  CATEGORY_VALUES = %w{after artist author addressee creator_of_work contributor engraver interviewee
                  interviewer manufacturer manner_of photographer printer printer_of_plates
                  publisher}

  include AttrJson::Model
  validates_presence_of :category, :value
  validates :category, inclusion:
    { in: CATEGORY_VALUES,
      allow_blank: true,
      message: "%{value} is not a valid category" }

  attr_json :category, :string
  attr_json :value, :string


end
