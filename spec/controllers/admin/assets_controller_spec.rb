require 'rails_helper'


RSpec.describe Admin::AssetsController, :logged_in_user, type: :controller do
  let(:cached_file_param) do
    bytestream = Rails.root + "spec/test_support/images/20x20.png"
    Shrine.storages[:cache].upload(bytestream, "attached_files/sample.png")

    [
      {
        "storage" => "cache",
        "id" => "attached_files/sample.png",
        "metadata" => {
          "filename" => "20x20.png"
        }
      }.to_json
    ]
  end

  let(:parent_work) { create(:work, published: false) }
  let(:parent_collection) { create(:collection) }

  describe "index", logged_in_user: :staff_viewer do
    render_views
    let!(:assets) { [create(:asset, parent: parent_work), create(:asset, parent: parent_collection )] }
    it "shows list of regular assets and thumbnails without error" do
      get :index
      expect(response).to have_http_status(200)
     end
  end

  describe "non-thumbnail asset smoke tests", logged_in_user: :editor do
    render_views
    let(:asset) {  create(:asset, parent: parent_work) }
    it "show" do
      get :show, params: { id: asset.friendlier_id}
      expect(response).to have_http_status(200)
    end
    it "edit" do
      get :edit, params: { id: asset.friendlier_id}
      expect(response).to have_http_status(200)
    end
  end

  describe "collection thumbnail smoke tests", logged_in_user: :editor do
    render_views
    let(:asset) { create(:asset, parent: parent_collection )}
    it "show" do
      get :show, params: { id: asset.friendlier_id}
      expect(response).to have_http_status(200)
    end
  end

  describe "#destroy"  do
    let(:asset) { create(:asset, parent: create(:work) ) }

    describe "as admin role", logged_in_user: :admin do
      it "destroys" do
        put :destroy, params: { id: asset.friendlier_id}

        expect { asset.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect(response).to redirect_to(admin_work_path(asset.parent.friendlier_id, anchor: "tab=nav-members"))
      end

      describe "with content indexed in work" do
        let(:asset) do
          Kithe::Indexable.index_with(disable_callbacks: true) do
            create(:asset, transcription: "transcription text to be deleted", published: true )
          end
        end
        let!(:parent_work) do
          Kithe::Indexable.index_with(disable_callbacks: true) do
            create(:work, members: [asset, create(:asset, transcription: "to be retained", published: true)])
          end
        end


        let(:solr_update_url_regex) { /^#{Regexp.escape(ScihistDigicoll::Env.lookup!(:solr_url) + "/update/json")}/ }

        it "triggers correct work re-index", indexable_callbacks: true do
          stub_request(:any, solr_update_url_regex)
          put :destroy, params: { id: asset.friendlier_id}

          # this is ugly way to test that transcription was NOT included in the
          # work re-index, which was a bug we had to fix.
          expect(WebMock).to have_requested(:post, solr_update_url_regex).with { |req|
            record = JSON.parse(req.body).first
            expect(record["searchable_fulltext_language_agnostic"]).to include("to be retained")
            expect(record["searchable_fulltext_language_agnostic"]).not_to include("transcription text to be deleted")
          }
        end
      end
    end
  end

  describe "#attach_files", logged_in_user: :editor do
    it "creates and attaches Asset" do
      post :attach_files, params: { parent_id: parent_work, cached_files: cached_file_param }

      cached_file_param.each do |json|
        file_param = JSON.parse(json)
        child = parent_work.members.find { |a| a.original_filename == file_param["metadata"]["filename"] }
        expect(child).to be_present
        expect(child.published).to eq(parent_work.published)
      end
    end

    describe "with published parent" do
      let(:parent_work) { create(:work, :published) }
      it "attaches asset as published" do
        post :attach_files, params: { parent_id: parent_work, cached_files: cached_file_param }
        expect(parent_work.members).to be_present
        expect(parent_work.members.all? { |m| m.published? }).to be true
      end

    end
  end

  describe "#update", logged_in_user: :editor do
    let(:parent_work) { create(:work) }
    context "asset with ocr suppressed" do
      let(:asset) {  create(:asset, parent: parent_work, suppress_ocr:true, "ocr_admin_note"=>"some note") }
      it "enqueues a WorkOcrCreatorRemoverJob when suppress_ocr is turned off" do
        expect {
          put :update, params: { asset: { suppress_ocr: "0" }, id: asset.friendlier_id }
        }.to have_enqueued_job(WorkOcrCreatorRemoverJob).with { |w| expect(w.friendlier_id).to eq parent_work.friendlier_id }
        expect(flash[:notice]).to match /Asset was successfully updated./
        expect(response).to have_http_status(302)
      end
    end
    context "asset with ocr on" do
      let(:asset) {  create(:asset, parent: parent_work, suppress_ocr:false) }
      it "enqueues a WorkOcrCreatorRemoverJob when suppress_ocr is turned on" do
        expect {
          put :update, params: {
            asset: { suppress_ocr: 1, ocr_admin_note: "cause i said so" },
            id: asset.friendlier_id
          }
        }.to have_enqueued_job(WorkOcrCreatorRemoverJob).with { |w| expect(w.friendlier_id).to eq parent_work.friendlier_id }
        expect(flash[:notice]).to match /Asset was successfully updated./
        expect(response).to have_http_status(302)
      end
    end
  end

  # almost more of an integration test, we're going to do real stuff, it will be slow
  context "#setup_work_from_pdf_source", queue_adapter: :inline do
    let(:asset) do
      create(:asset, :inline_promoted_file,
              file: File.open(Rails.root + "spec/test_support/pdf/sample-text-and-image-small.pdf"),
              parent: create(:work))
    end

    it "properly sets up" do
      allow(PdfToPageImages).to receive(:new).and_call_original

      put :setup_work_from_pdf_source, params: {
        id: asset.friendlier_id
      }

      expect(PdfToPageImages).to have_received(:new)

      asset.reload

      expect(asset.role).to eq "work_source_pdf"
      expect(asset.parent.text_extraction_mode).to eq "pdf_extraction"

      # 1 pdf page extracted
      expect(asset.parent.members.where(role: PdfToPageImages::EXTRACTED_PAGE_ROLE).count).to eq 1

      # scaled down derivative created
      expect(asset.file_derivatives[AssetUploader::SCALED_PDF_DERIV_KEY]).to be_present
      expect(asset.file_derivatives[AssetUploader::SCALED_PDF_DERIV_KEY].content_type).to eq "application/pdf"
      expect(asset.file_derivatives[AssetUploader::SCALED_PDF_DERIV_KEY].size).to be > 0
    end
  end

  # Note: more extensive tests of the helper object are at asset_hocr_and_pdf_uploader_spec.rb
  context "Add an HOCR and a textonly_pdf file (smoke test)", logged_in_user: :editor do
    let(:valid_hocr_path) { Rails.root + "spec/test_support/hocr_xml/hocr.xml" }
    let(:valid_pdf_path)  { Rails.root + "spec/test_support/pdf/textonly.pdf" }
    let(:asset) {  create(:asset, parent: parent_work, hocr:nil, suppress_ocr: true, ocr_admin_note: "File was too wide") }
    it "can add HOCR and PDF" do
      put :submit_hocr_and_textonly_pdf, params: { id: asset.friendlier_id,
          hocr: Rack::Test::UploadedFile.new(valid_hocr_path, "application/xml"),
          textonly_pdf: Rack::Test::UploadedFile.new(valid_pdf_path, "application/xml")}
      expect(response).to redirect_to(admin_asset_url(asset.reload))
      expect(asset.hocr).to include "ocr_line"
      expect(asset.suppress_ocr).to be false
      deriv = asset.file_derivatives[:textonly_pdf]
      expect(deriv.size).to eq 7075
      expect(flash[:notice]).to eq "Updated HOCR and textonly_pdf."
    end
  end

  describe "#fixity_report", logged_in_user: :editor do
    context "report absent" do
      it "enqueues a 'create report' job" do
        expect { get :fixity_report }.to have_enqueued_job(CalculateFixityReportJob)
        expect(response).to have_http_status(200)
      end
    end
    context "report exists" do
      let(:report_date) { "2025-01-01 00:00:00 -0400" }
      let!(:rep) {
        FixityReport.new.tap do |rep|
          rep.update!( data_for_report: { "no_checks" => 0, "timestamp" =>report_date,
            "asset_count" => 0, "with_checks" => 0, "recent_count" => 0, "stale_checks" => 0
          })
        end
      }

      it "finds a report and passes it to the template after enqueuing a new calculate job" do
        expect { get :fixity_report }.to have_enqueued_job(CalculateFixityReportJob)
        expect(response).to have_http_status(200)
        expect(assigns(:fixity_report)[:timestamp]).to eq "2025-01-01 00:00:00 -0400"
        expect(assigns(:new_report_started)).to eq 'true'
      end

      context "recent report" do
        let(:report_date) { Time.current.to_s }
        it "finds a recent report and passes it to the template; does not attempt to recalculate" do
          expect {
           get :fixity_report
          }.not_to have_enqueued_job(CalculateFixityReportJob)
          expect(response).to have_http_status(200)
          expect(assigns(:fixity_report)[:timestamp]).to eq rep.data_for_report['timestamp']
          expect(assigns(:new_report_started)).to be_nil
         end
      end
    end
  end  
end
