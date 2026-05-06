namespace :scihist do
  namespace :oral_history do
    task :store_extracted_pdf_paragraphs => [:environment] do
      # no ohms
      scope = OralHistoryContent.where(ohms_xml_text: [nil, ""])

      # for now, only publicially accessible ones without request, we aren't
      # totally able to calculate offsets for non-public ones. This scope is currently
      # not great performance.
      scope = scope.available_immediate

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      errors = 0
      scope.find_each(batch_size: 10) do |oc|
        # TODO make it lazy optionally? or better based on freshness!
        if ENV['BG_JOB'] == "true"
          OralHistoryStoreExtractedParagraphsJob.set(queue: "special_jobs").perform_later(oc, allow_failure_to_sync: true)
        else
          begin
            OralHistoryContent::ParagraphContainer.create(oral_history_content: oc, allow_failure_to_sync: true)
          rescue StandardError => e
            errors += 1
            puts "store_extracted_pdf_paragraphs: error on oral_history_content #{oc.id}, work #{oc&.work&.friendlier_id}, #{e}\n\n"
          end
        end
        progress_bar.increment
      end

      if errors > 0
        puts "Errors in #{errors} / #{scope.count}"
      end
    end
  end
end
