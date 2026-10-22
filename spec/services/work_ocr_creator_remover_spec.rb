require 'rails_helper'

describe WorkOcrCreatorRemover, queue_adapter: :test do
  let(:image_asset_without_hocr) { create(:asset_with_faked_file) }
  let(:image_asset_with_ocr_suppressed) { create(:asset_with_faked_file, :suppress_ocr, title: "Asset with OCR suppressed") }
  let(:image_asset_with_ocr_suppressed_but_with_derivs) do
    create(:asset_with_faked_file,
      :suppress_ocr, title: "Asset with OCR suppressed BUT with derivs", hocr:'remove this hocr', faked_derivatives: {
        textonly_pdf: create(:stored_uploaded_file, content_type: "application/pdf")
      }
    )
  end

  let(:image_asset_with_hocr) do
    create(:asset_with_faked_file,
      hocr: "goat",
      faked_derivatives: {
        textonly_pdf: create(:stored_uploaded_file, content_type: "application/pdf")
      }
    )
  end
  let(:image_asset_with_hocr) do
    create(:asset_with_faked_file,
      hocr: "goat",
      faked_derivatives: {
        textonly_pdf: create(:stored_uploaded_file, content_type: "application/pdf")
      }
    )
  end

  let(:sound_asset) { create(:asset_with_faked_file, :m4a) }
  let(:child_work)  { create(:public_work, representative: create(:asset_with_faked_file)) }

  let(:work) do
    create(:public_work,
      language: 'English',
      ocr_requested: ocr_requested,
      members: [
        image_asset_without_hocr,
        image_asset_with_ocr_suppressed,
        image_asset_with_ocr_suppressed_but_with_derivs,
        image_asset_with_hocr,
        sound_asset,
        child_work
      ]
    )
  end

  context "work needs OCR" do
    let(:ocr_requested) { true }

    it "enqueues an ocr creation job for assets that need it; removes OCR and textonly_pdf from works that don't" do
      WorkOcrCreatorRemover.new(work).process
      expect(CreateAssetOcrJob).to have_been_enqueued.with(image_asset_without_hocr)
      expect(CreateAssetOcrJob).not_to have_been_enqueued.with(image_asset_with_hocr)
      expect(CreateAssetOcrJob).not_to have_been_enqueued.with(sound_asset)
      expect(CreateAssetOcrJob).not_to have_been_enqueued.with(child_work)
      expect(CreateAssetOcrJob).not_to have_been_enqueued.with(image_asset_with_ocr_suppressed)
      expect(CreateAssetOcrJob).not_to have_been_enqueued.with(image_asset_with_ocr_suppressed_but_with_derivs)
      image_asset_with_ocr_suppressed_but_with_derivs.reload
      expect(image_asset_with_ocr_suppressed_but_with_derivs.file_derivatives.keys).to eq []
      expect(image_asset_with_ocr_suppressed_but_with_derivs.hocr).to be_nil
    end

    context "but does not have suitable language metadata" do
      let(:work) do
        create(:public_work,
          language: [],
          ocr_requested: true,
          members: [
            image_asset_without_hocr,
            image_asset_with_hocr,
            sound_asset,
            child_work
          ]
        )
      end

      it "does not enqueue CreateAssetOcrJob" do
        WorkOcrCreatorRemover.new(work).process
        expect(CreateAssetOcrJob).not_to have_been_enqueued
      end
    end

    context "with extracted_pdf_page" do
      let(:asset) { create(:asset_with_faked_file, hocr: "test hocr", role: PdfToPageImages::EXTRACTED_PAGE_ROLE, faked_derivatives: {}) }
      let(:work) do
        create(:public_work,
          language: 'English',
          ocr_requested: true,
          members: [ asset ]
        )
      end

      it "does not enqueue CreateAssetOcrJob" do
        WorkOcrCreatorRemover.new(work).process
        expect(CreateAssetOcrJob).not_to have_been_enqueued
      end
    end
  end

  context "work does not need OCR" do
    let(:ocr_requested) { false }
    it "removes OCR" do
      WorkOcrCreatorRemover.new(work).process
      work.reload
      work.members.each do |m|
        expect(CreateAssetOcrJob).not_to have_been_enqueued.with(m)
        expect(m.hocr).to be_nil if m.asset?
        expect(m.file_derivatives[:textonly_pdf]).to be_nil if m.asset?
      end
    end

    context "with extracted_pdf_page" do
      let(:asset) { create(:asset_with_faked_file, hocr: "test hocr", role: PdfToPageImages::EXTRACTED_PAGE_ROLE, faked_derivatives: {}) }
      let(:work) do
        create(:public_work,
          ocr_requested: false,
          members: [ asset ]
        )
      end

      it "leaves hocr alone" do
        WorkOcrCreatorRemover.new(work).process

        expect(asset.reload.hocr).to eq "test hocr"
      end
    end
  end

  describe "handwriting transcription", queue_adapter: :test do
    let(:feature_flag) { true }
    let(:text_extraction_mode) { "handwriting_transcription" }
    let(:existing_request) { nil }
    let(:asset) { create(:asset_with_faked_file, handwriting_transcription: "Dear Cousin James") }
    let(:work) do
      create(:public_work,
        members: [asset],
        text_extraction_mode: text_extraction_mode,
        handwriting_transcription_request: existing_request
      )
    end

    before do
      allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
      allow(ScihistDigicoll::Env).to receive(:lookup).with(:gemini_htr_transcripts_feature_flag).and_return(feature_flag)
    end

    context "work in handwriting_transcription mode, never requested" do
      it "records status queued and enqueues a request" do
        WorkOcrCreatorRemover.new(work).process

        expect(work.reload.handwriting_transcription_request.status).to eq "queued"
        expect(HandwritingTranscriptionJob).to have_been_enqueued.with(work).once
      end

      it "does not enqueue a second request when run again" do
        WorkOcrCreatorRemover.new(work).process
        WorkOcrCreatorRemover.new(Work.find(work.id)).process

        expect(HandwritingTranscriptionJob).to have_been_enqueued.once
      end

      context "with feature flag off" do
        let(:feature_flag) { false }

        it "does nothing" do
          WorkOcrCreatorRemover.new(work).process

          expect(work.reload.handwriting_transcription_request).to be_nil
          expect(HandwritingTranscriptionJob).not_to have_been_enqueued
        end
      end
    end

    context "work in handwriting_transcription mode, with a failed request" do
      let(:existing_request) { { status: "failure", error: "Gemini was not available" } }

      it "does not request again" do
        WorkOcrCreatorRemover.new(work).process

        expect(work.reload.handwriting_transcription_request.status).to eq "failure"
        expect(HandwritingTranscriptionJob).not_to have_been_enqueued
      end
    end

    context "work no longer in handwriting_transcription mode, with a request" do
      let(:text_extraction_mode) { nil }
      let(:existing_request) { { status: "success" } }

      it "removes the transcription and forgets the request" do
        WorkOcrCreatorRemover.new(work).process

        expect(asset.reload.handwriting_transcription).to be_nil
        expect(work.reload.handwriting_transcription_request).to be_nil
        expect(HandwritingTranscriptionJob).not_to have_been_enqueued
      end

      context "with feature flag off" do
        let(:feature_flag) { false }

        it "leaves the transcription alone" do
          WorkOcrCreatorRemover.new(work).process

          expect(asset.reload.handwriting_transcription).to eq "Dear Cousin James"
          expect(work.reload.handwriting_transcription_request.status).to eq "success"
        end
      end
    end

    context "work not in handwriting_transcription mode, with no request" do
      let(:text_extraction_mode) { nil }

      it "does not reindex the work" do
        WorkOcrCreatorRemover.new(work).process

        expect(ReindexWorksJob).not_to have_been_enqueued
      end
    end
  end
end
