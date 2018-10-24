class Work::Place
  CATEGORY_VALUES = %w{place_of_interview place_of_manufacture place_of_publication place_of_creation}

  include AttrJson::Model

  validates_presence_of :category, :value
  validates :category, inclusion: { in: CATEGORY_VALUES }


  attr_json :category, :string
  attr_json :value, :string
end
