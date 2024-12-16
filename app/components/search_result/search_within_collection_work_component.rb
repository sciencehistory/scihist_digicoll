module SearchResult
  class SearchWithinCollectionWorkComponent < WorkComponent
    def box_and_folder
      @box_and_folder ||= archives? ? box_and_folder_string : nil
    end

    def box_and_folder_string
      @box_and_folder ||= [
        (box_id.present? ? "Box #{box_id}" : nil),
        (folder_id.present? ? "Folder #{folder_id}" : nil)
      ].compact.join (", ")
    end


    private

    def archives?
      model&.department == 'Archives'
    end

    def box_id
      model&.physical_container&.box
    end

    def folder_id
      model&.physical_container&.folder
    end
  end
end
