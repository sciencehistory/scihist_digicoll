class Work::Place
  TYPE_VOCAB = %w{place_of_interview place_of_manufacture place_of_publication place_of_creation}

  include AttrJson::Model

  attr_json :type, :string
  attr_json :value, :string
end
