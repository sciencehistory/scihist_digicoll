module SearchResult

  # A subclass of WorkComponent which just adds one additional public method,
  # which provides a string representation of the box and folder info.
  # Only designed for use on collection work pages.
  class SearchWithinCollectionWorkComponent < WorkComponent

  def initialize(model ,child_counter:, solr_document:nil, cart_presence:nil)
    unless model.work? && model&.department == 'Archives'
      raise "This is the wrong class to display this search result."
    end
    super
  end


    def box_and_folder
      @box_and_folder ||=  if display_box_and_folder?
        [
          (box_id.present?    ? "Box #{box_id}"       : nil),
          (folder_id.present? ? "Folder #{folder_id}" : nil)
        ].compact.join (", ")
      end
    end

    private

    def display_box_and_folder?
      model.work? && model&.department == 'Archives'
    end

    def box_id
      model&.physical_container&.box
    end

    def folder_id
      model&.physical_container&.folder
    end
  end
end
