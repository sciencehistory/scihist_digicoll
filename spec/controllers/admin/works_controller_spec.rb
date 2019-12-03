require 'rails_helper'

# mostly we use feature tests, but some things can't easily be tested that way
# Should this be a 'request' spec instead of a rspec 'controller' spec
# (that is a rails 'functional' test)?
RSpec.describe Admin::WorksController, :logged_in_user, type: :controller do
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
    end
  end
end
