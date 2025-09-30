require 'rails_helper'

RSpec.describe Admin::DigitizationQueueItemsController, :logged_in_user, type: :controller do
  describe "admin user", logged_in_user: :admin do

    let(:queue_item) { FactoryBot.create(:digitization_queue_item, title: "Newly scanned rare book") }

    before do
      Admin::QueueItemComment.new(
        digitization_queue_item_id: queue_item.id,
        text: "Some other user's comment",
        user_id:123
      ).save!
    end

    it "shows the list of DQ items" do
      get :index
      expect(response.code).to eq "200"
    end

    it "shows the new item form" do
      get :new
      expect(response.code).to eq "200"
    end

    it "sends email on creation", queue_adapter: :test do
      expect do
        post :create, params: {
            admin_digitization_queue_item: {
              collecting_area: queue_item.collecting_area,
              title: "newer item",
              accession_number: queue_item.accession_number
            }
        }
        expect(response.code).to eq "302"
        expect(flash[:notice]).to match /Digitization queue item was successfully created/
      end.to have_enqueued_job(ActionMailer::MailDeliveryJob).with { |class_name, action|
        expect(class_name).to eq "DigitizationQueueMailer"
        expect(action).to eq "new_item_email"
      }
      new_item = Admin::DigitizationQueueItem.all.last
      expect(new_item.collecting_area).to eq "archives"
      expect(new_item.title).to eq "newer item"
    end

    it "can add, then delete a comment" do
      expect(Admin::QueueItemComment.count).to eq 1
      post :add_comment, params: { comment: "my new comment", id: queue_item.id }
      expect(Admin::QueueItemComment.count).to eq 2
      newly_created = Admin::QueueItemComment.last
      expect(newly_created).to be_present
      expect(newly_created.text).to eq "my new comment"
      #now delete it
      post :delete_comment, params: { id: queue_item.id, comment_id: newly_created.id }
      expect(Admin::QueueItemComment.count).to eq 1
      # try deleting another user's comment
      cannot_delete_this_comment = Admin::QueueItemComment.last
      bad_delete = post :delete_comment, params: { id: queue_item.id, comment_id: cannot_delete_this_comment.id }
      expect(bad_delete.redirect?).to be true
      expect(bad_delete.request.flash[:notice]).to eq "You may not delete this comment."
      expect(Admin::QueueItemComment.count).to eq 1
    end

    it "shows an item" do
      post :show, params: {
        id: queue_item.id,
      }
      expect(response.code).to eq "200"
    end

    it "updates" do
      post :update, params: {
        id: queue_item.id,
        admin_digitization_queue_item: {
          title: "new_title",
          collecting_area: "rare_books",
          bib_number: "12345678",
          location: "shelf",
        }
      }
      expect(response.code).to eq "302"
      expect(flash[:notice]).to match /Digitization queue item was successfully updated/
      new_item = Admin::DigitizationQueueItem.all.last
      expect(new_item.collecting_area).to eq "rare_books"
      expect(new_item.title).to eq "new_title"
      expect(new_item.bib_number).to eq "12345678"
      expect(new_item.location).to eq "shelf"
    end

    describe "with attached work" do
      let(:queue_item) { create(:digitization_queue_item, title: "Newly scanned rare book", works: [create(:work)]) }
      it "can attach works from cart" do
        controller.current_user.works_in_cart = [
          create(:work, title: "1"),
          create(:work, title: "2"),
          create(:work, title: "3"),
          queue_item.works.first
        ]
        expect(controller.current_user.works_in_cart.count).to eq 4
        get :import_attached_works_from_cart,  params: { id: queue_item.id }
        expect(queue_item.reload.works.map {|i| i.title}.sort).to eq ["1", "2", "3", "Test title"]
      end

      it "denies deletion if there are works attached" do
        delete :destroy, params: { id: queue_item.id }

        expect(response.redirect?).to be true
        expect(response).to redirect_to(admin_digitization_queue_item_path(queue_item))
        expect(response.request.flash[:notice]).to eq "Can't delete Digitization Queue Item with attached works"
      end

      it "can detach the work"  do
        delete :delete_work_association, params: {id: queue_item.id, work_id: queue_item.works[0].id}
        expect(response).to redirect_to(admin_digitization_queue_item_path(queue_item))
        expect(response.request.flash[:notice]).to eq "Detached \"Test title\"."
        expect(queue_item.reload.works.length).to eq 0
      end
    end
  end
end
