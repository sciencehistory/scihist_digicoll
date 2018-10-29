class Work
  class PhysicalContainer
    include AttrJson::Model

    attr_json :box, :string
    attr_json :folder, :string
    attr_json :volume, :string
    attr_json :part, :string
    attr_json :page, :string
    attr_json :shelfmark, :string

  end
end
