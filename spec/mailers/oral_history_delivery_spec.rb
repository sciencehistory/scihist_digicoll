require "rails_helper"

RSpec.describe OralHistoryDeliveryMailer, :type => :mailer do
  describe "Sends out the items" do
    let(:members) do
      [
        create(:asset_with_faked_file, :mp3, published: false,
          oh_available_by_request: true, title: "Protected mp3", position: 0),
        create(:asset_with_faked_file, :pdf, published: false,
          oh_available_by_request: true,  title: "Protected PDF", position: 1),
        create(:asset_with_faked_file, :pdf, published: true,
          title: "Preview PDF", position: 2),
        create(:asset_with_faked_file, :pdf, published: false,
          title: "We will get sued if you send this out.", position: 3)
      ]
    end

    let!(:work) do
      create(:oral_history_work, published: true).tap do |work|
        work.members = members
        work.representative =  members[2]
        work.save!
        work.oral_history_content!.update(available_by_request_mode: :automatic)
      end
    end

    let(:request) { Admin::OralHistoryAccessRequest.create!(
        created_at: Time.parse("2020-10-01 12:00:00 +0000"),
        patron_name: "Patron name",
        patron_email: "patron@institution.com",
        patron_institution: "Institution",
        intended_use: "I will write so many books.",
        work: work
      )
    }

    let(:mail) { OralHistoryDeliveryMailer.
      with(request: request).
      oral_history_delivery_email }

    it "renders the headers" do
      expect(mail.subject).to eq("Science History Institute: files from Oral history interview with William John Bailey")
      expect(mail.to).to eq(["patron@institution.com"])
      expect(mail.from).to eq(["oralhistory@sciencehistory.org"])
    end

    it "renders the body; does not send items that are already publicly accessible" do
      body = mail.body.encoded
      # puts body
      expect(body).to match "Dear Patron name"
      expect(body).to match "On 10/01/2020, you requested access"
      expect(body).to match /Files for.*Bailey/
      expect(body).to match /Protected mp3.*MP3 — 56.9 KB.*Protected PDF.*PDF — 7.4 KB/m
      # The preview PDF is does not have oh_available_by_request set to true.
      # Thus, it should not get sent out in the email.
      expect(body).not_to match /Preview PDF/

      expect(body).not_to match /We will get sued/
    end

  end
end
