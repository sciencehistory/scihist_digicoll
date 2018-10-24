class Work::ExternalId
  CATEGORY_VALUES = %w{object bib item accn aspace interview}

  include AttrJson::Model

  validates_presence_of :category, :value
  validates :category, inclusion:
    { in: CATEGORY_VALUES,
      allow_blank: true,
      message: "%{value} is not a valid category" }

  attr_json :category, :string
  attr_json :value, :string
end
