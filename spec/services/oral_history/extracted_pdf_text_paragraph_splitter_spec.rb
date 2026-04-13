require 'rails_helper'

describe OralHistory::ExtractedPdfTextParagraphSplitter do
  let(:extracted_pdf_text) { OralHistory::ExtractPdfText.new(pdf_file_path: oh_pdf_path).extract_pdf_text }

  let(:splitter) { described_class.new(extracted_pdf_text: extracted_pdf_text) }

  describe "very old transcript" do
    let(:oh_pdf_path) { Rails.root + "spec/test_support/pdf/oh/rice_1984_sample_pages_fhb2l9q.pdf"}

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

    it "joins paragraphs split across pages, with marker" do
      paragraphs = splitter.paragraphs

      expect(paragraphs[9].text).to eq "About six miles south of Armagh which is the capital of <PAGE-BREAK next='2'></PAGE-BREAK> Northern Ireland, I think. It's a historic little town. Our home was right on the border between Ulster and the Free State, although technically in Ulster. I think I have a picture someplace of the house."
      expect(paragraphs[9].pdf_logical_page_number).to eq 1
    end
  end

  describe "old transcript with upper page numbers" do
    let(:oh_pdf_path) { Rails.root + "spec/test_support/pdf/oh/prelog_1984_sample_pages_2514nm37q.pdf"}

    it "can still get page numbers" do
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
      expect(paragraphs.last.pdf_logical_page_number).to eq 33


      expect(paragraphs.collect(&:pdf_logical_page_number).uniq).to eq [1,2,3,32,33]
    end
  end

  describe "mid-era transcript, with minute timestamp style" do
    let(:oh_pdf_path) { Rails.root + "spec/test_support/pdf/oh/Macfarlane_1982_sample_pages_subbr8.pdf"}

    it "extracts timestamps" do
      paragraphs = splitter.paragraphs

      paragraph_with_timestamp = paragraphs.find { |p| p.text.start_with?("—for your particular problem")}
      expect(paragraph_with_timestamp).to be_present

      expect(paragraph_with_timestamp.included_timestamps).to eq [15*60]
    end

    it "extracts reasonable pages with metadata" do
      paragraphs = splitter.paragraphs

      expect(paragraphs).to all(be_kind_of(OralHistoryContent::Paragraph))
      expect(paragraphs).to all(have_attributes(
        paragraph_index: be_present, pdf_logical_page_number: be_present, text: be_present)
      )

      # all page numbers are increasing
      expect(paragraphs.each_cons(2)).to all(satisfy { |a, b| a.pdf_logical_page_number <= b.pdf_logical_page_number })

      # Some details of the PDF we know and check, first and last paragraphs
      expect(paragraphs.first.pdf_logical_page_number).to eq 1
      # we skipped some internal pages in this sample
      expect(paragraphs.last.pdf_logical_page_number).to eq 103

      # everyone has a speaker name or assumed_speaker_name, but not both.
      # Wow it's the XOR operatopr
      expect(paragraphs).to all(satisfy { |p| p.speaker_name.present? ^ p.assumed_speaker_name.present? })

      expect(paragraphs.collect(&:speaker_name).uniq.compact.sort).to eq ["GRAYSON", "MACFARLANE"]
    end

    it "joins paragraphs" do
      paragraphs = splitter.paragraphs

      joined_paragraph = paragraphs.find { |p| p.text.start_with?("So, I got the darn thing working, and") }
      expect(joined_paragraph).to be_present
      expect(joined_paragraph.text).to end_with("I had the whole field to myself.")
      expect(joined_paragraph.pdf_logical_page_number).to eq 8
      expect(joined_paragraph.text).to include "<PAGE-BREAK next='9'></PAGE-BREAK>"
    end
  end


  describe "newer transcript, with new style per-paragraph timestamps" do
    let(:oh_pdf_path) { Rails.root + "spec/test_support/pdf/oh/glusker_2022_sample_pages_ebnw2l9.pdf"}

    it "extracts timestamps" do
      paragraphs = splitter.paragraphs

      # there are two paragraphs that don't have timestamps, the [END OF...] ones maybe we should be
      # stripping, but here they are
      expect(paragraphs).to all(satisfy { |p| p.included_timestamps.present? || p.text.start_with?("[END OF") })
    end

    it "extracts reasonable pages with metadata" do
      paragraphs = splitter.paragraphs

      expect(paragraphs).to all(be_kind_of(OralHistoryContent::Paragraph))
      expect(paragraphs).to all(have_attributes(
        paragraph_index: be_present, pdf_logical_page_number: be_present, text: be_present)
      )

      # all page numbers are increasing
      expect(paragraphs.each_cons(2)).to all(satisfy { |a, b| a.pdf_logical_page_number <= b.pdf_logical_page_number })

      expect(paragraphs.collect(&:speaker_name).uniq.compact.sort).to eq ["BOYTIM", "GLUSKER", "SCHNEIDER"]

      # Check first paragraph and selected paragraphs
      expect(paragraphs.first.speaker_name).to eq "SCHNEIDER"
      expect(paragraphs.first.text).to start_with("So today is Tuesday, November 1, 2022.")
      expect(paragraphs.first.included_timestamps).to eq [0]
      expect(paragraphs.first.pdf_logical_page_number).to eq 1

      # paragraph 5 is assumed speaker name AND should be joined to end on next page
      expect(paragraphs[4].speaker_name).to be_nil
      expect(paragraphs[4].assumed_speaker_name).to eq "GLUSKER"
      expect(paragraphs[4].text).to match %r{\AAnd my father’s father.*<PAGE-BREAK next='2'></PAGE-BREAK>.*I don’t know if you can turn that around\.\Z}
      expect(paragraphs[4].included_timestamps).to eq [91]
      expect(paragraphs[4].pdf_logical_page_number).to eq 1
    end
  end
end
