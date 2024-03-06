require "rails_helper"

RSpec.describe OralHistoryDeliveryMailer, :type => :mailer do
  describe "Sends out the items" do
    let(:representative) do
      create(:asset_with_faked_file, :pdf, published: true, title: "Preview PDF", position: 1)
    end

    let(:members) do
      [
        representative,
        create(:asset_with_faked_file, :mp3, published: false,
          oh_available_by_request: true, title: "Protected mp3", faked_filename: "Protected mp3", position: 2),
        create(:asset_with_faked_file, :pdf, published: false,
          oh_available_by_request: true,  title: "Protected PDF", faked_filename: "Protected PDF", position: 3),
        create(:asset_with_faked_file, :pdf, published: false,
          title: "We will get sued if you send this out.", position: 4)
      ]
    end

    let!(:work) do
      create(:oral_history_work, :published).tap do |work|
        work.members = members
        work.representative =  representative
        work.save!
        work.oral_history_content!.update(available_by_request_mode: :automatic)
      end
    end

    let(:request) { OralHistoryRequest.create!(
        created_at: Time.parse("2020-10-01 12:00:00 +0000"),
        patron_name: "Patron name",
        oral_history_requester: OralHistoryRequester.create_or_find_by(email: "patron@institution.com"),
        patron_institution: "Institution",
        intended_use: "I will write so many books.",
        work: work
      )
    }

    let(:staff_message) { "A message to you, Rudy."}

    let(:mail) { OralHistoryDeliveryMailer.
      with(request: request, custom_message: staff_message).
      oral_history_delivery_email }

    it "renders the headers" do
      expect(mail.subject).to eq("Science History Institute: files from Oral history interview with William John Bailey")
      expect(mail.to).to eq(["patron@institution.com"])
      expect(mail.from).to eq(["oralhistory@sciencehistory.org"])
    end

    it "renders the body; does not send items that are already publicly accessible" do
      body = mail.body.encoded

      expect(body).to match "Dear Patron name"
      expect(body).to match /files from.*Bailey/

      expect(body).to match /Protected mp3.*MP3.*Protected PDF.*PDF/m

      expect(body).to match "Please download your files by #{(Date.today + 6.days).strftime("%A, %B %d")}"

      expect(body).to include RightsTerm.label_for(work.rights)

      expect(body).to include(staff_message)

      # The preview PDF is does not have oh_available_by_request set to true.
      # Thus, it should not get sent out in the email.
      expect(body).not_to match /Preview PDF/
    end

  end
end
