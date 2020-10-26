require 'rails_helper'

describe "work_file_list_show system test", type: :system, js: true do
  let(:preview_pdf) { create(:asset_with_faked_file, :pdf, published: true) }
  let(:protected_pdf) { create(:asset_with_faked_file, :pdf, published: false, oh_available_by_request: true) }
  let(:protected_mp3) { create(:asset_with_faked_file, :mp3, published: false, oh_available_by_request: true) }


  let!(:work) do
    create(:oral_history_work, published: true).tap do |work|
      work.members << preview_pdf
      work.members << protected_pdf
      work.members << protected_mp3

      work.representative =  preview_pdf
      work.save!

      work.oral_history_content!.update(available_by_request_mode: :automatic)
    end
  end

  context "When you visit an OH with protected by request assets" do
    it "shows the page without error" do
      visit work_path(work.friendlier_id)

      expect(page).to have_selector("h1", text: work.title)

      expect(page).to have_selector("h2", text: "Access this interview")
      expect(page).to have_text("1 PDF transcript and 1 audio recording file")
      expect(page).to have_selector(:link_or_button, 'Request Access')

      within(".show-member-file-list-item") do
        expect(page).to have_selector(:link, preview_pdf.title)
        expect(page).to have_selector(:link_or_button, "Download")
      end

      click_on 'Request Access'
      pr = '#admin_oral_history_access_request_'

      all("#{pr}patron_name").first.fill_in  with: 'Joe Schmo'
      all("#{pr}patron_email").first.fill_in with: 'patron@library.org'
      all("#{pr}patron_institution").first.fill_in with: 'Some Library'
      all("#{pr}intended_use").first.fill_in with: 'Fun & games'

      expect(Admin::OralHistoryAccessRequest.count).to eq 0

      ActiveJob::Base.queue_adapter = :test

      click_on 'Submit request'

      expect(Admin::OralHistoryAccessRequest.count).to eq 1

      new_req = Admin::OralHistoryAccessRequest.last
      expect(new_req.patron_name).to eq "Joe Schmo"
      expect(new_req.patron_email).to eq "patron@library.org"
      expect(new_req.patron_institution).to eq "Some Library"
      expect(new_req.intended_use).to eq "Fun & games"

      # expect(page).to have_text("Your request has been logged.")
    end
  end
end
