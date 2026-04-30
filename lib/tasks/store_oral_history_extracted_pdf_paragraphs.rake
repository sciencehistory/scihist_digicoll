namespace :scihist do
  namespace :oral_history do

    task :enqueue_store_extracted_pdf_paragraphs => [:environment] do
      # no ohms
      scope = OralHistoryContent.where(ohms_xml_text: [nil, ""])

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_each do |oc|
        # TODO make it lazy optionally? or better based on freshness!
        OralHistoryStoreExtractedParagraphsJob.set(queue: "special_jobs").perform_later(oc)
        progress_bar.increment
      end
    end
  end
end
