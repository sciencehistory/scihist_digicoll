require 'rails_helper'

describe OralHistory::ExtractPdfText do
  let(:old_oh_sample_pages_pdf_path) { Rails.root + "spec/test_support/pdf/oh/old_sample_pages_rice_b2l9q.pdf"}

  describe "#extract_pdf_text" do
    it "extracts text from an older oh pdf" do
      as_json = described_class.new(pdf_file_path: old_oh_sample_pages_pdf_path).extract_pdf_text

      expect(as_json).to be_kind_of(Hash)
      expect(as_json).to be_present
    end

    describe "schema-invalid JSON from python tool" do
      let(:extracter) do
        described_class.new(pdf_file_path: old_oh_sample_pages_pdf_path).tap do |obj|
          fake_cmd = instance_double(TTY::Command)
          allow(fake_cmd).to receive(:run).and_return([
            { "pages": [
                "bad_key": "I don't even know"
              ]
            }.to_json,
            ""
          ])

          allow(obj).to receive(:extract_pdf_text_tty_command).and_return(fake_cmd)
        end
      end

      it "raises error" do
        expect { extracter.extract_pdf_text }.to raise_error(OralHistory::ExtractPdfText::Error)
      end
    end

    describe "error from shell" do
      let(:extracter) do
        described_class.new(pdf_file_path: old_oh_sample_pages_pdf_path).tap do |obj|
          allow(obj).to receive(:extract_pdf_text_command).and_return("false") # bash command to fail
        end
      end

      it "raises error" do
        expect { extracter.extract_pdf_text }.to raise_error(OralHistory::ExtractPdfText::Error)
      end
    end
  end


end
