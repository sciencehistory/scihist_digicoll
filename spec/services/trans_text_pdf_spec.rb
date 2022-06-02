require 'rails_helper'

describe TransTextPdf do
  describe "Multi-page work with transcription and translation" do
    let(:work) do
      create(:public_work, :with_complete_metadata,
        members: [
          create(:asset_with_faked_file, position: 1, transcription: "This is file-1 transcription\n\ntranscription paragraph two", english_translation: "This is file-1 translation\n\ntranslation paragraph two"),
          create(:asset_with_faked_file, position: 2, transcription: "This is file-2 transcription", english_translation: "This is file-2 translation")
        ]
      )
    end

    it "raises on unrecogtnized mode" do
      expect {
        TransTextPdf.new(work, mode: :unknown)
      }.to raise_error(ArgumentError)
    end

    # It's too hard to actually test against content of PDF, but we'll make sure it
    # happens without raising at least!
    it "produces prawn_pdf for :transcription without errors" do
      expect(TransTextPdf.new(work, mode: :transcription).prawn_pdf).to be_kind_of Prawn::Document
    end

    it "produces prawn_pdf for :english_translation without errors" do
      expect(TransTextPdf.new(work, mode: :english_translation).prawn_pdf).to be_kind_of Prawn::Document
    end

    # but mostly we'll check the intermediate HTML, and even here not exhaustively
    describe "#content_html" do
      describe "transcription" do
        let(:html_txt) { TransTextPdf.new(work, mode: :transcription).content_html }
        let(:html_obj) { Nokogiri::HTML(html_txt) }
        let(:work_path) {
          Rails.application.routes.url_helpers.work_url(work, host: ScihistDigicoll::Env.app_url_base_parsed.host)
        }

        it "includes url" do
          expect(html_obj.css("a[href='#{work_path}']")).to be_present
        end

        it "inclues transcript text" do
          expect(html_txt).to include("<p>This is file-1 transcription</p>")
          expect(html_txt).to include("<p>transcription paragraph two</p>")
          expect(html_txt).to include("This is file-2 transcription")
        end

        it "does not include translation text" do
          expect(html_txt).not_to include("This is file-1 translation")
        end
      end

      describe "english_translation" do
        let(:html_txt) { TransTextPdf.new(work, mode: :english_translation).content_html }
        let(:html_obj) { Nokogiri::HTML(html_txt) }

        it "inclues translation text" do
          expect(html_txt).to include("<p>This is file-1 translation</p>")
          expect(html_txt).to include("<p>translation paragraph two</p>")
          expect(html_txt).to include("This is file-2 translation")
        end

        it "does not include transcription text" do
          expect(html_txt).not_to include("This is file-1 transcription")
        end
      end
    end
  end

  describe "html formatting and sanitization" do
    let(:work) do
      create(:public_work, :with_complete_metadata,
        members: [
          create(:asset_with_faked_file, position: 1, transcription: "paragraph 1 <b>bold</b>\n\nparagraph 2 <script>unsafe</script>"),
        ]
      )
    end

    let(:html_txt) { TransTextPdf.new(work, mode: :transcription).content_html }

    it "works" do
      expect(html_txt).to include("<p>paragraph 1 <b>bold</b></p>")
      expect(html_txt).to include("<p>paragraph 2 unsafe</p>")
    end
  end
end
