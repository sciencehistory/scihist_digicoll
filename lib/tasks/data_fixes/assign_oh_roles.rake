namespace :scihist do
  namespace :data_fixes do

    desc "assign 'role' to legacy Oral History assets"
    task :assign_oh_roles => :environment do
      scope = Work.includes(:members).where("json_attributes -> 'genre' ?  'Oral histories'")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_each do |work|

        if work.members.size == 0
          # nevermind, we don't care
          next
        end

        pdfs = work.members.find_all {|a| a.is_a?(Asset) && a.content_type == "application/pdf"}

        # only PDF and it's published? Transcript
        if pdfs.count == 1 && pdfs.first.published?
          one_pdf = pdfs.first
          one_pdf.update(role: "transcript")

        # Two pdfs, one is published, and one is by-request? The by-request one is
        # transccript, the published one is front-matter.
        elsif pdfs.count == 2 &&
          transcript = pdfs.find { |a| !a.published? && a.oh_available_by_request? }
          front_matter = pdfs.find { |a| a.published? }

          if transcript && front_matter
            transcript.update(role: "transcript")
            front_matter.update(role: "front_matter")
          end

        # don't know how to do it!
        else
          progress_bar.log "Couldn't figure out what to do with OH work: #{work.friendlier_id}"

        end

        progress_bar.increment
      end
    end
  end
end
