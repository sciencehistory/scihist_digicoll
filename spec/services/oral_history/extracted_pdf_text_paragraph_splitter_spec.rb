require 'rails_helper'

describe OralHistory::ExtractedPdfTextParagraphSplitter do
  let(:oh_pdf_path) { Rails.root + "spec/test_support/pdf/oh/old_sample_pages_rice_b2l9q.pdf"}
  let(:extracted_pdf_text) { OralHistory::ExtractPdfText.new(pdf_file_path: oh_pdf_path).extract_pdf_text }

  let(:splitter) { described_class.new(extracted_pdf_text: extracted_pdf_text) }

  it "extracts good paragraphs" do
    paragraphs = splitter.paragraphs

    expect(paragraphs).to all(be_kind_of(OralHistoryContent::Paragraph))
    expect(paragraphs).to all(have_attributes(
      paragraph_index: be_present, pdf_logical_page_number: be_present, text: be_present)
    )
    # this one does not have timestamps
    expect(paragraphs).to all(have_attributes(included_timestamps: be_blank))

    # all page numbers are increasing
    expect(paragraphs.each_cons(2)).to all(satisfy { |a, b| a.pdf_logical_page_number <= b.pdf_logical_page_number })

    # Some details of the PDF we know and check, first and last paragraphs
    expect(paragraphs.first.pdf_logical_page_number).to eq 1
    # we skipped some internal pages in this sample
    expect(paragraphs.last.pdf_logical_page_number).to eq 25

    # Check known first and last paragraphs, including up-casing of speaker name, and removal
    # from text.
    expect(paragraphs.first.speaker_name).to eq "HEITMANN"
    expect(paragraphs.first.text).to start_with "I'm with Dr. Francis O. Rice in South Bend,Indiana."

    expect(paragraphs.last.speaker_name).to eq "HEITMANN"
    expect(paragraphs.last.text).to eq "I think I'll close the taping for now. Thank you for the interview, Dr. Rice."
  end


end
