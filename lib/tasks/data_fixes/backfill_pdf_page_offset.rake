namespace :scihist do
  namespace :data_fixes do

    desc """
      Calculate and add logical_page_number_offset to OralHistoryContent where required
    """
    task :backfill_pdf_page_offset => :environment do
      scope = OralHistoryContent.includes(:work => :members).
        where("json_attributes -> 'extracted_pdf_paragraphs' is not null").
        where("json_attributes -> 'extracted_pdf_paragraphs' -> 'logical_page_number_offset' is null")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      scope.find_each(batch_size: 10) do |oral_history_content|
        pdf_asset = oral_history_content.work.members.find { |a| a.respond_to?(:role) && a.role == "transcript" }

        unless pdf_asset
          progress_bar.log "Could not create for #{oral_history_content.work.friendlier_id}, missing pdf_asset"
          next
        end

        extracted_pdf_text_json = pdf_asset.file_derivatives[:extracted_pdf_text_json]

        unless extracted_pdf_text_json
          progress_bar.log "Could not create for #{oral_history_content.work.friendlier_id}, missing extracted_pdf_text_json"
          next
        end

        extracted_pdf_text = JSON.parse(extracted_pdf_text_json.read)

        splitter = OralHistory::PdfParagraphSplitter.new(
          extracted_pdf_text: extracted_pdf_text,
          allow_failure_to_sync: true
        )
        splitter.paragraphs # trigger calculation

        offset = splitter.logical_page_number_offset

        unless offset
          progress_bar.log "Could not create for #{oral_history_content.work.friendlier_id}, could not find offset"
          next
        end

        oral_history_content.extracted_pdf_paragraphs.logical_page_number_offset = splitter.logical_page_number_offset
        oral_history_content.save!

        progress_bar.increment
      end
    end
  end
end
