class OralHistoryStoreExtractedParagraphsJob < ApplicationJob

  # TODO extract this to a method in OralHistoryContent, yeah.
  def perform(oral_history_content)
    pdf_file = oral_history_content.work.members.where(role: "transcript").first

    unless pdf_file
      raise "#{self.class.name}: Could not find a pdf file for OralHistory for work #{oral_history_content.work.friendlier_id}"
    end

    extracted_pdf_text_json = pdf_file.file_derivatives[:extracted_pdf_text_json]

    unless extracted_pdf_text_json
      raise "#{self.class.name} could not find extracted_pdf_text_json derivative from asset #{pdf_file.friendlier_id}"
    end

    extracted_pdf_text = JSON.parse(extracted_pdf_text_json.read)

    paragraphs = OralHistory::ExtractedPdfTextParagraphSplitter.new(
      extracted_pdf_text: extracted_pdf_text,
      file_start_times: oral_history_content.combined_audio_component_metadata["start_times"].to_h
    ).paragraphs

    container = OralHistoryContent::ParagraphContainer.create(
        paragraphs: paragraphs,
        oral_history_content: oral_history_content,
        pdf_asset: pdf_file
    )

    oral_history_content.extracted_pdf_paragraphs = container
    oral_history_content.save!
  end
end
