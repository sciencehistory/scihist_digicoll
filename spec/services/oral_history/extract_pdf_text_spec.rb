require 'rails_helper'

describe OralHistory::ExtractPdfText do
  let(:old_oh_sample_pages_pdf_path) { Rails.root + "spec/test_support/pdf/oh/rice_1984_sample_pages_fhb2l9q.pdf"}

  describe "#extract_pdf_text" do
    it "extracts text from an older oh pdf" do
      as_json = described_class.new(pdf_file_path: old_oh_sample_pages_pdf_path).extract_pdf_text

      expect(as_json).to be_kind_of(Hash)
      expect(as_json).to be_present
    end

    describe "source_text_is_ocr" do
      # two pages from an ocrmypdf'd PDF -- p1 has a paragraph PyMuPDF's own block
      # detection spuriously splits in two; p2 has a trailing page-number-only block.
      let(:ocr_sample_pages_pdf_path) { Rails.root + "spec/test_support/pdf/oh/benfey_o_0094_ocr_sample_pages.pdf" }

      # something we were having trouble doing with OCR'd text before some changes
      it "properly forms paragraphs and still finds page number" do
        as_json = described_class.new(pdf_file_path: ocr_sample_pages_pdf_path, source_text_is_ocr: true).extract_pdf_text

        page1_paragraphs = as_json["pages"][0]["blocks"][0]["paragraphs"]
        expect(page1_paragraphs.count).to eq(7)
        expect(page1_paragraphs[4]["text"]).to start_with(
          "Friends of ours, the Mendl family, had emigrated to England maybe two years earlier, to establish a London branch of a German firm"
        )
        page1_last_block_paragraphs = as_json["pages"][0]["blocks"].last["paragraphs"]
        expect(page1_last_block_paragraphs.count).to eq(1)
        expect(page1_last_block_paragraphs.first["text"]).to eq("4")

        page2_last_block_paragraphs = as_json["pages"][1]["blocks"].last["paragraphs"]
        expect(page2_last_block_paragraphs.count).to eq(1)
        expect(page2_last_block_paragraphs.first["text"]).to eq("10")
      end

      describe "dirtier OCR page numbers" do
        # one page where OCR noise splits the page number ("1") and a stray "."
        # into two separate raw lines within the same block, instead of one clean line
        let(:ocr_sample_pages_pdf_path) { Rails.root + "spec/test_support/pdf/oh/hyde_jf_0026_ocr_sample_page.pdf" }

        it "correctly isolates page number in it's own block" do
          as_json = described_class.new(pdf_file_path: ocr_sample_pages_pdf_path, source_text_is_ocr: true).extract_pdf_text

          last_block_paragraphs = as_json["pages"][0]["blocks"].last["paragraphs"]
          expect(last_block_paragraphs.count).to eq(1)
          expect(last_block_paragraphs.first["text"]).to eq("1 .")
        end
      end
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

    describe "bad unparseable JSON from python tool" do
      let(:extracter) do
        described_class.new(pdf_file_path: old_oh_sample_pages_pdf_path).tap do |obj|
          fake_cmd = instance_double(TTY::Command)
          allow(fake_cmd).to receive(:run).and_return([
            "{ this is bad json }",
            ""
          ])

          allow(obj).to receive(:extract_pdf_text_tty_command).and_return(fake_cmd)
        end
      end

      it "raises error" do
        expect { extracter.extract_pdf_text }.to raise_error(OralHistory::ExtractPdfText::Error)
      end
    end

  end


end
