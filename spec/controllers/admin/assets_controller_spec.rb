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
end
