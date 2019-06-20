class Work
  class Creator
    CATEGORY_VALUES = %w{addressee after artist attributed_to author
                    contributor creator_of_work editor engraver interviewee
                    interviewer manufacturer manner_of photographer
                    printer printer_of_plates publisher school_of}

    include AttrJson::Model
    validates_presence_of :category, :value
    validates :category, inclusion:
      { in: CATEGORY_VALUES,
        allow_blank: true,
        message: "%{value} is not a valid category" }

    attr_json :category, :string
    attr_json :value, :string


  end
end
