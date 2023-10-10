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

  context "Add an HOCR and a textonly_pdf file", logged_in_user: :editor do

    let(:valid_hocr_path) { Rails.root + "spec/test_support/hocr_xml/hocr.xml" }
    let(:bad_hocr_path)   { Rails.root + "spec/test_support/ohms_xml/smythe_OH0042.xml"}
    let(:valid_pdf_path)  { Rails.root + "spec/test_support/pdf/textonly.pdf" }
    let(:bad_pdf_path)    { Rails.root + "spec/test_support/pdf/tiny.pdf"}

    let(:asset) {  create(:asset, parent: parent_work, hocr:nil) }

    it "can add HOCR and PDF" do
      put :submit_hocr_and_textonly_pdf, params: { id: asset.friendlier_id,
          suppress_ocr: true,
          hocr: Rack::Test::UploadedFile.new(valid_hocr_path, "application/xml"),
          textonly_pdf: Rack::Test::UploadedFile.new(valid_pdf_path, "application/xml")}
      expect(response).to redirect_to(admin_asset_url(asset.reload))

      expect(asset.hocr).to include "ocr_line"
      expect(asset.suppress_ocr).to be false

      deriv = asset.file_derivatives[:textonly_pdf]
      expect(deriv).to be_present
      expect(deriv).to be_a AssetUploader::UploadedFile
      expect(deriv.size).to eq 7075
      expect(deriv.metadata).to be_present

      expect(flash[:notice]).to eq "Updated HOCR and textonly_pdf."
    end

    it "doesn't accept just the HOCR" do
      put :submit_hocr_and_textonly_pdf, params: { id: asset.friendlier_id,
          hocr: Rack::Test::UploadedFile.new(valid_hocr_path, "application/xml"),
          textonly_pdf: ""}
      expect(response).to redirect_to(admin_asset_url(asset))
      expect(flash[:error]).to eq "Please provide a textonly_pdf and an hocr."
    end

    it "doesn't accept just the PDF" do
      put :submit_hocr_and_textonly_pdf, params: { id: asset.friendlier_id,
          textonly_pdf: Rack::Test::UploadedFile.new(valid_pdf_path, "application/xml")}
      expect(response).to redirect_to(admin_asset_url(asset))
      expect(flash[:error]).to eq "Please provide a textonly_pdf and an hocr."
    end

    it "won't accept bad OCR" do
      put :submit_hocr_and_textonly_pdf, params: { id: asset.friendlier_id,
        hocr: Rack::Test::UploadedFile.new(bad_hocr_path, "application/xml"),
        textonly_pdf: Rack::Test::UploadedFile.new(valid_pdf_path, "application/xml")
      }
      expect(response).to redirect_to(admin_asset_url(asset))
      expect(flash[:error]).to eq "This HOCR file isn't valid."
      expect(asset.reload.hocr).to be_nil
    end

    it "won't accept bad textonly_pdf" do
      put :submit_hocr_and_textonly_pdf, params: { id: asset.friendlier_id,
        hocr: Rack::Test::UploadedFile.new(valid_hocr_path, "application/xml"),
        textonly_pdf: Rack::Test::UploadedFile.new(bad_pdf_path, "application/xml"),
      }
      expect(response).to redirect_to(admin_asset_url(asset))
      expect(flash[:error]).to eq "This PDF isn't valid."
      expect(asset.reload.file_derivatives[:textonly_pdf]).to be_nil
    end

    describe "already has a textonly_pdf" do
      let(:asset) { create(:asset_with_faked_file,
        faked_derivatives: { textonly_pdf: FactoryBot.build(:stored_uploaded_file, content_type: "application/pdf") },
        hocr: Rack::Test::UploadedFile.new(valid_hocr_path, "application/xml")
        )
      }
      it "replaces the old derivative" do
        expect(asset.file_derivatives[:textonly_pdf].metadata["size"]).to eq 2750
        put :submit_hocr_and_textonly_pdf, params: { id: asset.friendlier_id,
          hocr: Rack::Test::UploadedFile.new(valid_hocr_path, "application/xml"),
          textonly_pdf: Rack::Test::UploadedFile.new(valid_pdf_path, "application/xml")
        }
        expect(asset.reload.file_derivatives[:textonly_pdf].metadata["size"]).to eq 7075
      end
    end
  end
end
