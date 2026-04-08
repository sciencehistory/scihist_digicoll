require 'rails_helper'

describe OralHistory::ExtractPdfText do
  let(:old_oh_sample_pages_pdf_path) { Rails.root + "spec/test_support/pdf/oh/old_sample_pages_rice_b2l9q.pdf"}

  describe "#extract_pdf_text" do
    it "extracts text from an older oh pdf" do
      as_json = described_class.new(pdf_file_path: old_oh_sample_pages_pdf_path).extract_pdf_text

      expect(as_json).to be_kind_of(Hash)
      expect(as_json).to be_present
    end
  end

end
