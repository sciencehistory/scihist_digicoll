class Work
  class PhysicalContainer
    include AttrJson::Model

    attr_json :box, :string
    attr_json :folder, :string
    attr_json :volume, :string
    attr_json :part, :string
    attr_json :page, :string
    attr_json :shelfmark, :string


    # A simple string consistent with what chf_sufia did
    def display_as
      values = []
      values << "Box #{box}" if box.present?
      values << "Folder #{folder}" if folder.present?
      values << "Volume #{volume}" if volume.present?
      values << "Part #{part}" if part.present?
      values << "Page #{page}" if page.present?
      values << "Shelfmark #{shelfmark}" if shelfmark.present?

      values.join(", ")
    end
  end
end
