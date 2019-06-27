class Work
  class Inscription
    include AttrJson::Model

    validates :location, :text, presence: true

    attr_json :location, :string
    attr_json :text, :string

    def display_as
      "(#{location}) \"#{text}\""
    end

  end
end
