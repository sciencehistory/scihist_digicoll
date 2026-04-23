module OralHistory

  # Preview in dev at:
  #
  #  http://localhost:3000/rails/view_components/oral_history/paragraph_transcript_component/
  class ParagraphTranscriptComponentPreview < ViewComponent::Preview

    def with_live_parsed_data
      file_start_times = { "9ccaf328-1626-470f-aed2-2a040a6e2d4b" => 0, "a8057542-4191-4bd3-a7c8-455ba958c1b6" => 9115.82 }

      paragraphs = compute_paragraphs_from_pdf(
        pdf_file_path: Rails.root + "spec/test_support/pdf/oh/macfarlane_1982_sequence_timestamps_example.pdf",
        file_start_times: file_start_times
      )
      render(ParagraphTranscriptComponent.new(paragraphs))
    end

    private

    # @param file_start_times [Hash] can be real start times from OH, but doesn't need to be so long
    #   as has right number of files.
    def compute_paragraphs_from_pdf(pdf_file_path:, file_start_times:)
      extracted_pdf_text = OralHistory::ExtractPdfText.new(pdf_file_path: pdf_file_path).extract_pdf_text

      splitter = OralHistory::ExtractedPdfTextParagraphSplitter.new(extracted_pdf_text: extracted_pdf_text, file_start_times: file_start_times)

      splitter.paragraphs
    end
  end
end
