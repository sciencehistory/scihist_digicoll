require 'rails_helper'

# Note: we have two Works controllers,
# works_controller.rb
# admin/works_controller.rb
# This one tests only the second.

# mostly we use feature tests, but some things can't easily be tested that way
# Should this be a 'request' spec instead of a rspec 'controller' spec
# (that is a rails 'functional' test)?
RSpec.describe Admin::WorksController, :logged_in_user, type: :controller, queue_adapter: :test do
  context "#demote_to_asset" do
    context "work not suitable" do
      context "becuase it has no parent" do
        let(:work) { FactoryBot.create(:work, :with_assets)}

        it "rejects" do
          put :demote_to_asset, params: { id: work.friendlier_id }

          expect(response).to redirect_to admin_work_path(work)
          expect(flash[:alert]).to match /Can't convert/
        end
      end

      context "becuase it has multiple assets" do
        let(:parent_work) { FactoryBot.create(:work) }
        let(:work) { FactoryBot.create(:work, :with_assets, asset_count: 5, parent: parent_work)}

        it "rejects" do
          put :demote_to_asset, params: { id: work.friendlier_id }

          expect(response).to redirect_to admin_work_path(work)
          expect(flash[:alert]).to match /Can't convert/
        end
      end
    end
  end

  context "add an OHMS XML file" do
    let(:valid_xml_path) { Rails.root + "spec/test_support/ohms_xml/duarte_OH0344.xml" }

    let(:work) { FactoryBot.create(:work, genre: ["Oral histories"]) }

    it "can add valid file" do
      put :submit_ohms_xml, params: { id: work.friendlier_id, ohms_xml: Rack::Test::UploadedFile.new(valid_xml_path, "application/xml")}
      expect(response).to redirect_to(admin_work_path(work, anchor: "nav-oral-histories"))
      expect(flash[:error]).to be_blank

      expect(work.reload.oral_history_content.ohms_xml).to be_present
    end

    it "can't add an invalid file" do
      put :submit_ohms_xml, params: {
        id: work.friendlier_id,
        ohms_xml: Rack::Test::UploadedFile.new(StringIO.new("not > xml"), "application/xml", original_filename: "foo.xml")
      }

      expect(response).to redirect_to(admin_work_path(work, anchor: "nav-oral-histories"))
      expect(flash[:error]).to include("OHMS XML file was invalid and could not be accepted")

      expect(work.reload.oral_history_content&.ohms_xml).not_to be_present
    end
  end

  context "create audio derivatives" do
    let(:no_audio_files) { FactoryBot.create(:work, genre: ["Oral histories"]) }
    let!(:oral_history) { FactoryBot.create(:work,
      genre: ["Oral histories"],
      title: "Oral history with two interview audio segments")
    }
    let!(:audio_asset_1)  { create(:asset, :inline_promoted_file,
        position: 1,
        parent_id: oral_history.id,
        file: File.open((Rails.root + "spec/test_support/audio/ice_cubes.mp3"))
      )
    }
    let!(:audio_asset_2)  { create(:asset, :inline_promoted_file,
        position: 2,
        parent_id: oral_history.id,
        file: File.open((Rails.root + "spec/test_support/audio/double_ice_cubes.mp3"))
      )
    }

    it "only creates files if the item is an oral history" do
      put :create_combined_audio_derivatives, params: { id: no_audio_files.friendlier_id }
      expect(response).to redirect_to(admin_work_path(no_audio_files, anchor: "nav-oral-histories"))
      expect(flash[:error]).to include("This oral history doesn't have any audio files.")
    end

    it "kicks off an audio derivatives job" do
      expect(oral_history.members.map(&:stored?)).to match([true, true])
      put :create_combined_audio_derivatives, params: { id: oral_history.friendlier_id }
      expect(response).to redirect_to(admin_work_path(oral_history, anchor: "nav-oral-histories"))
      expect(CreateCombinedAudioDerivativesJob).to have_been_enqueued
    end
  end

  context "protected to logged in users" do
    context "without a logged-in user", logged_in_user: false do
      it "redirects to login" do
        get :index
        expect(response).to redirect_to(new_user_session_path)
      end
    end

    context "with a logged-in user", logged_in_user: true do
      it "shows page" do
        get :index
        expect(response).not_to be_redirect
        expect(response.status).to eq(200)
      end
    end
  end

  context "protected to admin users" do
    let(:work) { create(:work) }

    context "with a logged-in non-admin user" do
      it "can not publish" do
        put :publish, params: { id: work.friendlier_id }
        expect(response.status).to redirect_to(root_path)
        expect(flash[:alert]).to match /You don't have permission/
      end

      it "can not delete" do
        put :destroy, params: { id: work.friendlier_id }
        expect(response.status).to redirect_to(root_path)
        expect(flash[:alert]).to match /You don't have permission/
      end
    end

    context "with a logged-in admin user", logged_in_user: :admin do
      # works that have the necessary metadata to be published, but aren't actually published yet
      let(:work_child) { build(:work, :published, published: false) }
      let(:asset_child) { build(:asset, published: false) }
      let(:work) { create(:work, :published, published: false, members: [asset_child, work_child]) }

      it "can publish, and publishes children" do
        put :publish, params: { id: work.friendlier_id }
        expect(response.status).to redirect_to(admin_work_path(work))

        work.reload
        expect(work.published?).to be true
        expect(work.members.all? {|m| m.published?}).to be true
      end

      it "can delete, and deletes children" do
        put :destroy, params: { id: work.friendlier_id }
        expect(response.status).to redirect_to(admin_works_path)
        expect(flash[:notice]).to match /was successfully destroyed/

        expect { work.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { work_child.reload }.to raise_error(ActiveRecord::RecordNotFound)
        expect { asset_child.reload }.to raise_error(ActiveRecord::RecordNotFound)
      end

      context "work missing required fields for publication" do
        render_views

        let(:work) { create(:private_work, rights: nil, format: nil, genre: nil, department: nil, date_of_work: nil) }

        it "can not publish, displaying proper error and work form" do
          put :publish, params: { id: work.friendlier_id }

          expect(response.status).to be(200)

          expect(response.body).to include("Can&#39;t publish work: #{work.title}: Validation failed")
          expect(response.body).to include("Date can&#39;t be blank for published works")
          expect(response.body).to include("Rights can&#39;t be blank for published works")
          expect(response.body).to include("Format can&#39;t be blank for published works")
          expect(response.body).to include("Genre can&#39;t be blank for published works")
          expect(response.body).to include("Department can&#39;t be blank for published works")
        end

        describe "child work missing required fields" do
          let(:work_child) { build(:private_work) }
          let(:work) { create(:work, :published, published: false, members: [work_child]) }

          it "can not publish, displaing proper error for child work" do
            put :publish, params: { id: work.friendlier_id }
            expect(response.status).to be(200)
            expect(response.body).to include("Can&#39;t publish work: #{work_child.title}: Validation failed")
          end
        end
      end

      context "published work" do
        let(:work_child) { build(:public_work) }
        let(:asset_child) { build(:asset, published: true) }
        let(:work) { create(:public_work, members: [asset_child, work_child]) }


        it "can unpublish, unpublishes children" do
          put :unpublish, params: { id: work.friendlier_id }
          expect(response.status).to redirect_to(admin_work_path(work))

          work.reload
          expect(work.published?).to be false
          expect(work.members.none? {|m| m.published?}).to be true
        end
      end
    end
  end
end
