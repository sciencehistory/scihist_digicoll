require 'rails_helper'

describe DownloadsController do
  let(:faked_download_url) { "http://test.host/faked_download_url" }
  # We're not actually using S3 in test, but we want to make sure
  # we're sending the right params to S3 url generation.
  # So we mock it out.
  #
  # This does run the risk that if we send keys that don't do what we
  # assume for real S3, we're not going to catch it in tests.
  # But we haven't figured out a better way for now.
  before do
    @received_s3_url_args = []

    allow_any_instance_of(Shrine::UploadedFile).to receive(:url) do |**args|
      @received_s3_url_args << args
      faked_download_url
    end
  end


  describe "#original" do
    let(:file_category) { "image" }

    describe "non-existing ID" do
      it "raises not found" do
        expect {
          get :original, params: { asset_id: "no_such_id", file_category: file_category }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "no access asset" do
      let(:asset) { create(:asset, published: false) }
      it "redirects to login page" do
        get :original, params: { asset_id: asset, file_category: file_category }
        expect(response).to redirect_to root_path
      end
    end

    describe "by-request only asset" do
      let(:work) { create(:oral_history_work, :available_by_request) }
      let(:asset) { work.members.find { |m| m.oh_available_by_request? } }

      describe "with permission, when logged in" do
        let!(:approved_request) { create(:oral_history_request, work: work, delivery_status: "approved") }

        before do
          # mock signed-in OH requester
          OralHistorySessionsController.store_oral_history_current_requester(request: request, oral_history_requester: approved_request.oral_history_requester)
        end

        it "returns redirect to file" do
          get :original, params: { asset_id: asset, file_category: file_category }
          expect(response.status).to eq 302
          expect(response).not_to redirect_to(root_path)
          expect(response.location).to eq faked_download_url
        end
      end

      describe "logged in, but no request" do
        let(:oral_history_requester) { OralHistoryRequester.new(email: "example#{rand(999999)}@example.com") }
        before do
          # mock signed-in OH requester
          OralHistorySessionsController.store_oral_history_current_requester(request: request, oral_history_requester: oral_history_requester)
        end

        it "redirects to login page" do
          get :original, params: { asset_id: asset, file_category: file_category }
          expect(response).to redirect_to root_path
        end
      end
    end

    describe "non-promoted file" do
      let(:asset) { create(:asset, :inline_promoted_file, :non_promoted_file) }

      it "does not give access" do
        expect {
          get :original, params: { asset_id: asset, file_category: file_category }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "good file" do
      let(:asset) { create(:asset_with_faked_file,
                           faked_derivatives: {},
                           position: 12,
                           parent: create(:work, title: "Plastics make the package Dow makes the plastics"))
      }
      let(:expected_filename) {
        "plastics_make_the_#{asset.parent.friendlier_id}_#{asset.position}_#{asset.friendlier_id}.jpeg"
      }

      it "returns redirect" do
        get :original, params: { asset_id: asset, file_category: file_category }

        expect(response.status).to eq 302 # temporary redirect

        expect(@received_s3_url_args.length).to eq 1
        s3_url_args = @received_s3_url_args.first

        expect(s3_url_args[:response_content_type]).to eq asset.content_type
        expect(s3_url_args[:expires_in]).to eq DownloadsController::URL_EXPIRES_IN

        expect(s3_url_args[:response_content_disposition]).to start_with("attachment;")
        expect(s3_url_args[:response_content_disposition]).to include(expected_filename)
      end

      it "uses disposition inline when specified" do
        get :original, params: { asset_id: asset, disposition: "inline", file_category: file_category }

        expect(response.status).to eq 302 # temporary redirect

        expect(@received_s3_url_args.length).to eq 1
        s3_url_args = @received_s3_url_args.first

        expect(s3_url_args[:response_content_disposition]).to start_with("inline;")
        expect(s3_url_args[:response_content_disposition]).to include(expected_filename)
      end
    end

    describe "with turnstile protection" do
      include WebmockTurnstileHelperMethods

      let(:asset) { create(:asset_with_faked_file,
                           faked_derivatives: {},
                           parent: create(:work, title: "Plastics make the package Dow makes the plastics"))}

      before do
        allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
        allow(ScihistDigicoll::Env).to receive(:lookup).with(:cf_turnstile_downloads_enabled).and_return(true)
      end

      it "denies if no turnstile token present" do
        get :original, params: { asset_id: asset, file_category: file_category }
        expect(response).to have_http_status(403)
      end

      it "denies with bad turnstile token present" do
        stub_turnstile_failure(request_body: {"secret"=>BotDetectController.cf_turnstile_secret_key, "response"=>"bad", "remoteip"=>request.ip})

        get :original, params: { asset_id: asset, file_category: file_category, cf_turnstile_response: "bad" }
        expect(response).to have_http_status(403)
      end

      it "redirects with good turnstile token present" do
        stub_turnstile_success(request_body: {"secret"=>BotDetectController.cf_turnstile_secret_key, "response"=>"good", "remoteip"=>request.ip})

        get :original, params: { asset_id: asset, file_category: file_category, cf_turnstile_response: "good" }
        expect(response).to have_http_status(302)

        expect(@received_s3_url_args.length).to eq 1
        s3_url_args = @received_s3_url_args.first
        expect(s3_url_args[:response_content_disposition]).to start_with("attachment;")
      end
    end
  end


  describe "#derivative" do
    describe "non-existing ID" do
      it "raises not found" do
        expect {
          get :derivative, params: { asset_id: "no_such_id", derivative_key: "thumb_mini" }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "no access asset" do
      let(:asset) { create(:asset, published: false) }
      it "redirects to login page" do
        get :derivative, params: { asset_id: asset, derivative_key: "thumb_mini" }
        expect(response).to redirect_to root_path
      end
    end

    describe "derivative does not exist" do
      let(:asset) { create(:asset_with_faked_file, faked_derivatives: {}) }

      it "raises not found" do
        expect {
          get :derivative, params: { asset_id: asset, derivative_key: "thumb_mini" }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "by-request only asset" do
      let(:work) { create(:oral_history_work, :available_by_request_flac) }
      let!(:asset) { work.members.find { |m| m.oh_available_by_request? && m.content_type == "audio/flac" } }

      describe "with permission, when logged in" do
        let!(:approved_request) { create(:oral_history_request, work: work, delivery_status: "approved") }

        before do
          # mock signed-in OH requester
          OralHistorySessionsController.store_oral_history_current_requester(request: request, oral_history_requester: approved_request.oral_history_requester)
        end

        it "returns redirect to file" do
          get :derivative, params: { asset_id: asset, derivative_key: asset.file_derivatives.keys.first }
          expect(response.status).to eq 302
          expect(response).not_to redirect_to root_path
          expect(response.location).to eq faked_download_url
        end
      end

      describe "logged in, but no request" do
        let(:oral_history_requester) { OralHistoryRequester.new(email: "example#{rand(999999)}@example.com") }
        before do
          # mock signed-in OH requester
          OralHistorySessionsController.store_oral_history_current_requester(request: request, oral_history_requester: oral_history_requester)
        end

        it "redirects to login page" do
          get :derivative, params: { asset_id: asset, derivative_key: asset.file_derivatives.keys.first }
          expect(response).to redirect_to root_path
        end
      end
    end

    describe "good derivative" do
      let(:asset) { create(:asset_with_faked_file,
                           faked_derivatives: { :thumb_mini => build(:stored_uploaded_file, content_type: "image/jpeg") },
                           position: 12,
                           parent: create(:work, title: "Plastics make the package Dow makes the plastics"))
      }
      let(:derivative_key) { "thumb_mini"}
      let(:expected_filename) {
        # note it's jpeg not png for the derivative
        "plastics_make_the_#{asset.parent.friendlier_id}_#{asset.position}_#{asset.friendlier_id}_thumb_mini.jpeg"
      }

      it "redirects to asset with good filename" do
        get :derivative, params: { asset_id: asset, derivative_key: derivative_key }

        expect(response.status).to eq 302 # temporary redirect

        expect(@received_s3_url_args.length).to eq 1
        s3_url_args = @received_s3_url_args.first

        expect(s3_url_args[:response_content_disposition]).to start_with("attachment;")
        expect(s3_url_args[:response_content_disposition]).to include(expected_filename)
      end
    end
  end
end
