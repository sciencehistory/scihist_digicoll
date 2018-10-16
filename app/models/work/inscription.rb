class Work::Inscription
  include AttrJson::Model

  attr_json :location, :string
  attr_json :text, :string
end
