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

    it "can show a new DQ item form" do
      get :new, params: { collecting_area: 'archives' }
      expect(response.code).to eq "200"
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

    it "sends email on creation", queue_adapter: :test do
      expect do
        post :create, params: {
            collecting_area: queue_item.collecting_area,
            admin_digitization_queue_item: {
              title: "new item #{Time.now}",
              collecting_area: queue_item.collecting_area,
              accession_number: queue_item.accession_number
            }
        }

        expect(flash[:notice]).to match /Digitization queue item was successfully created/
      end.to have_enqueued_job(ActionMailer::MailDeliveryJob).with { |class_name, action|
        expect(class_name).to eq "DigitizationQueueMailer"
        expect(action).to eq "new_item_email"
      }
    end

  end
end
