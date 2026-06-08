namespace :scihist do
  namespace :data_fixes do

    desc """
      Migrate already stored PDF paragraph text from OralHistoryContent#extracted_pdf_paragraphs to
      #extracted_paragraph_container. Pursuant to https://github.com/sciencehistory/scihist_digicoll/pull/3471

    """
    task :migrate_oh_paragraph_data => :environment do
      progress_bar = ProgressBar.create(total: OralHistoryContent.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      OralHistoryContent.find_each(batch_size: 10) do |oc|
        if oc.extracted_paragraph_container.nil? && oc.json_attributes["extracted_pdf_paragraphs"]
          oc.extracted_paragraph_container = oc.json_attributes["extracted_pdf_paragraphs"]
          oc.json_attributes.delete("extracted_pdf_paragraphs")
        oc.save!
        end
        GC.start

        progress_bar.increment
      end
    end
  end
end
