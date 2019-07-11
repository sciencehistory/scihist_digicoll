require 'rails_helper'

describe DownloadsController do

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
      "http://test.host/faked_download_url"
    end
  end


  describe "#original" do
    describe "non-existing ID" do
      it "raises not found" do
        expect {
          get :original, params: { asset_id: "no_such_id" }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "no access asset" do
      let(:asset) { create(:asset, published: false) }
      it "redirects to login page" do
        get :original, params: { asset_id: asset }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "non-promoted file" do
      let(:asset) { create(:asset, :inline_promoted_file, :non_promoted_file) }

      it "does not give access" do
        expect {
          get :original, params: { asset_id: asset }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "good file" do
      let(:asset) { create(:asset_with_faked_file,
                           faked_derivatives: [],
                           position: 12,
                           parent: create(:work, title: "Plastics make the package Dow makes the plastics"))
      }
      let(:expected_filename) {
        "plastics_make_the_#{asset.parent.friendlier_id}_#{asset.position}_#{asset.friendlier_id}.png"
      }

      it "returns redirect" do
        get :original, params: { asset_id: asset }

        expect(response.status).to eq 302 # temporary redirect

        expect(@received_s3_url_args.length).to eq 1
        s3_url_args = @received_s3_url_args.first

        expect(s3_url_args[:response_content_type]).to eq asset.content_type
        expect(s3_url_args[:expires_in]).to eq DownloadsController::URL_EXPIRES_IN

        expect(s3_url_args[:response_content_disposition]).to start_with("attachment;")
        expect(s3_url_args[:response_content_disposition]).to include(expected_filename)
      end

      it "uses disposition inline when specified" do
        get :original, params: { asset_id: asset, disposition: "inline" }

        expect(response.status).to eq 302 # temporary redirect

        expect(@received_s3_url_args.length).to eq 1
        s3_url_args = @received_s3_url_args.first

        expect(s3_url_args[:response_content_disposition]).to start_with("inline;")
        expect(s3_url_args[:response_content_disposition]).to include(expected_filename)
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
        get :original, params: { asset_id: asset, derivatives_key: "thumb_mini" }
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    describe "derivative does not exist" do
      let(:asset) { create(:asset_with_faked_file, faked_derivatives: []) }

      it "raises not found" do
        expect {
          get :derivative, params: { asset_id: asset, derivative_key: "thumb_mini" }
        }.to raise_error(ActiveRecord::RecordNotFound)
      end
    end

    describe "good derivative" do
      let(:asset) { create(:asset_with_faked_file,
                           faked_derivatives: [ build(:faked_derivative, uploaded_file: build(:stored_uploaded_file, content_type: "image/jpeg")) ],
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
