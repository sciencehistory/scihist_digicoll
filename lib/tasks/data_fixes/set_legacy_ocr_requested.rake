namespace :scihist do
  namespace :data_fixes do

    desc """
      Set ocr_requested to true for works matching spec'd criteria
    """
    task :set_legacy_ocr_requested => :environment do
      total = Work.jsonb_contains(format: "text", language: "English", department: "Library").count +
                Work.jsonb_contains(format: "text", language: "English", department: "Archives").count

      progress_bar = ProgressBar.create(total: total, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      # Selection One:
      #
      # Format: Text
      # Language: English
      # Department: Library
      # Date: Post-1860 (Modern Library Materials)

      ocr_enabled_count = 0

      Work.jsonb_contains(format: "text", language: "English", department: "Library").find_each do |work|
        if work.date_of_work.any? {|d| d.start&.split("-")&.first.to_i >= 1860 }
          work.ocr_requested = true
          work.save!

          WorkOcrCreatorRemoverJob.set(queue: "special_jobs").perform_later

          ocr_enabled_count += 1
        end

        progress_bar.increment
      end

      # Selection Two:
      #
      # Format: Text
      # Language: English
      # Department: Archives
      # Date: Post-1900
      # Genre: Advertisements OR Pamphlets OR Handbooks and Manuals OR Publications

      Work.jsonb_contains(format: "text", language: "English", department: "Archives").find_each do |work|
        if work.date_of_work.any? {|d| d.start&.split("-")&.first.to_i >= 1900 } &&
            work.genre.any? {|g| ["Advertisements", "Pamphlets", "Handbooks", "Manuals", "Publications"].include?(g) }

            work.ocr_requested = true
            work.save!

            WorkOcrCreatorRemoverJob.set(queue: "special_jobs").perform_later

            ocr_enabled_count += 1
        end

        progress_bar.increment
      end

      puts "\nOCR enabled for #{ocr_enabled_count} works"
    end
  end
end
