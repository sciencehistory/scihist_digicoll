class Work
  class AdditionalCredit
    CATEGORY_VALUES = %w{photographer}

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
