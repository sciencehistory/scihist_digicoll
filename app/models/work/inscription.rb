class Work
  class Inscription
    include AttrJson::Model

    validates :location, :text, presence: true

    attr_json :location, :string
    attr_json :text, :string
  end
end
