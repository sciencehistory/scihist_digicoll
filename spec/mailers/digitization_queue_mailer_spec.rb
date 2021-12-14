require "rails_helper"

RSpec.describe DigitizationQueueMailer, :type => :mailer do
  describe "#new_item_email" do
    let(:digization_queue_item) { create(:digitization_queue_item) }

    it "executes without errors" do
      mail = DigitizationQueueMailer.with(digitization_queue_item: digization_queue_item).new_item_email
      expect(mail.to).to be_present
      expect(mail.from).to be_present
      expect(mail.subject).to be_present
      expect(mail.body).to be_present
    end
  end
end
