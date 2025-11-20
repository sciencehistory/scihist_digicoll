require 'rails_helper'

# Testing Oral History show page for OH's with assets available only by request. These use
# a different template than other ones.
#
describe "Oral History with by-request delivery", type: :system, js: true, queue_adapter: :test do
  let(:preview_pdf) { create(:asset_with_faked_file, :pdf, published: true) }
  let(:protected_pdf) { create(:asset_with_faked_file, :pdf, published: false, oh_available_by_request: true) }
  let(:protected_mp3) { create(:asset_with_faked_file, :mp3, published: false, oh_available_by_request: true) }
  let(:portrait) { create(:asset_with_faked_file, role: "portrait")}


  context "When you visit an OH with protected by request, automatic delivery assets" do
    let!(:work) do
      build(:oral_history_work, :published, members: [preview_pdf, protected_pdf, protected_mp3, portrait], representative: preview_pdf).tap do |work|
        work.oral_history_content!.update(available_by_request_mode: :automatic)
      end
    end

    it "shows the page without error" do
      visit work_path(work.friendlier_id)

      expect(page).to be_axe_clean

      expect(page).to have_selector("h1", text: work.title)

      # portrait
      expect(page).to have_selector(".oh-portrait img[src='#{portrait.file_url(:thumb_standard)}']")

      # Biographical metadata, just test a sampling
      expect(page).to have_selector("h2", text: "Interviewee biographical information")
      expect(page).to have_text(FormatSimpleDate.new(work.oral_history_content.interviewee_biographies.first.birth.date).display)
      expect(page).to have_text(FormatSimpleDate.new(work.oral_history_content.interviewee_biographies.first.birth.city).display)
      expect(page).to have_text(FormatSimpleDate.new(work.oral_history_content.interviewee_biographies.first.death.date).display)
      expect(page).to have_text(FormatSimpleDate.new(work.oral_history_content.interviewee_biographies.first.death.city).display)

      expect(page).to have_text work.oral_history_content.interviewee_biographies.first.job.first.institution
      expect(page).to have_text work.oral_history_content.interviewee_biographies.first.job.first.role
      expect(page).to have_text work.oral_history_content.interviewee_biographies.first.job.first.start.slice(0..3)

      expect(page).to have_text work.oral_history_content.interviewee_biographies.first.school.first.institution
      expect(page).to have_text work.oral_history_content.interviewee_biographies.first.school.first.date.slice(0..3)
      expect(page).to have_text work.oral_history_content.interviewee_biographies.first.school.first.degree
      expect(page).to have_text work.oral_history_content.interviewee_biographies.first.school.first.discipline

      expect(page).to have_text work.oral_history_content.interviewee_biographies.first.honor.first.start_date.slice(0..4)
      expect(page).to have_text work.oral_history_content.interviewee_biographies.first.honor.first.honor

      ## File request

      expect(page).to have_selector("h2", text: "Access this interview")
      expect(page).to have_text("1 PDF Transcript File")
      expect(page).to have_text("1 Audio Recording File")
      expect(page).to have_selector(:link_or_button, 'Get Access')

      within(".show-member-file-list-item") do
        expect(page).to have_selector(:link, preview_pdf.title)
        expect(page).to have_selector(:link_or_button, "Download")
      end

      expect(page).to have_text("Fill out a brief form to receive immediate access to these files.")

      click_on 'Get Access'

      expect(page).to have_selector(".modal") # now in modal
                                              #
      pr = '#oral_history_request_'

      all("#{pr}patron_name").first.fill_in  with: 'Joe Schmo'
      all("#{pr}oral_history_requester").first.fill_in with: 'patron@library.org'
      all("#{pr}patron_institution").first.fill_in with: 'Some Library'
      # leave out intended use, because not required for this request type, make sure it goes through

      expect(OralHistoryRequest.count).to eq 0

      click_on 'Submit request'


      expect(page).to have_selector(".modal") # now in modal
      expect(page).to have_text("The files you have requested are immediately available")
      expect(OralHistoryRequest.count).to eq 1

      new_req = OralHistoryRequest.last
      expect(new_req.patron_name).to eq "Joe Schmo"
      expect(new_req.requester_email).to eq "patron@library.org"
      expect(new_req.patron_institution).to eq "Some Library"
      expect(new_req.delivery_status_automatic?).to be(true)

      expect(page).to have_text("We've sent an email to patron@library.org with a sign-in link")

      expect(ActionMailer::MailDeliveryJob).to have_been_enqueued
    end
  end


  context "When you visit an OH with protected by request, approved delivery assets" do
    let!(:work) do
      build(:oral_history_work, :published, members: [preview_pdf, protected_pdf, protected_mp3], representative: preview_pdf).tap do |work|
        work.oral_history_content!.update(available_by_request_mode: :manual_review)
      end
    end

    it "shows the page without error" do
      visit work_path(work.friendlier_id)

      expect(page).to have_selector("h1", text: work.title)

      expect(page).to have_selector("h2", text: "Access this interview")
      expect(page).to have_text("1 PDF Transcript File")
      expect(page).to have_text("1 Audio Recording File")
      expect(page).to have_selector(:link_or_button, 'Request Access')

      within(".show-member-file-list-item") do
        expect(page).to have_selector(:link, preview_pdf.title)
        expect(page).to have_selector(:link_or_button, "Download")
      end

      expect(page).to have_text("Fill out a brief form and a staff member will review your request for these files. You should receive an email within 3 business days.")

      click_on 'Request Access'
      pr = '#oral_history_request_'

      expect(page).to have_selector(".modal") # now in modal
      expect(page).to have_text("After your request is received, you will receive an email response, usually within 3 business days. ")

      all("#{pr}patron_name").first.fill_in  with: 'Joe Schmo'
      all("#{pr}oral_history_requester").first.fill_in with: 'patron@library.org'
      all("#{pr}patron_institution").first.fill_in with: 'Some Library'
      all("#{pr}intended_use").first.fill_in with: 'Fun & games'

      expect(OralHistoryRequest.count).to eq 0
      click_on 'Submit request'

      expect(page).to have_selector(".modal") # now in modal
      expect(page).to have_text("Your request will be reviewed")
      expect(OralHistoryRequest.count).to eq 1

      new_req = OralHistoryRequest.last
      expect(new_req.patron_name).to eq "Joe Schmo"
      expect(new_req.requester_email).to eq "patron@library.org"
      expect(new_req.patron_institution).to eq "Some Library"
      expect(new_req.intended_use).to eq "Fun & games"
      expect(new_req.delivery_status_pending?).to be(true)


      expect(ActionMailer::MailDeliveryJob).to have_been_enqueued
    end
  end

  describe "when you visit an OH with nothing available at all period", js: false do
    let!(:work) do
      build(:oral_history_work, :published, members: [build(:asset_with_faked_file, :pdf, role: :transcript, published: false)]).tap do |work|
        work.oral_history_content!.update(available_by_request_mode: :off)
      end
    end

    it "shows no files and shows message" do
      visit work_path(work.friendlier_id)

      expect(page).to have_text("This oral history is currently unavailable. Please see the description of this interview to learn more about its future availability")
      expect(page).to have_text("If you have any questions about transcripts, recordings, or usage permissions, contact the Center for Oral History at oralhistory@sciencehistory.org")

      expect(page).not_to have_selector(".show-member-file-list-item")
      expect(page).not_to have_text(work.members.first.title)
    end
  end

  describe "for multiple requests", js: false do
    let(:work1) { create(:oral_history_work, :available_by_request, published: true) }
    let(:work2) { create(:oral_history_work, :available_by_request, published: true) }

    let(:patron_name) { "My Name" }
    let(:patron_email) { "me@example.com" }
    let(:patron_institution) { "University of wherever"}
    let(:intended_use) { "for fun" }

    it "remembers form entry" do
      visit oral_history_request_form_path(work1.friendlier_id)

      pr = '#oral_history_request_'

      find("#{pr}patron_name").fill_in  with: patron_name
      find("#{pr}oral_history_requester").fill_in with: patron_email
      find("#{pr}patron_institution").fill_in with: patron_institution
      find("#{pr}intended_use").fill_in with: intended_use


      click_on 'Submit request'

      expect(page).to have_selector(".modal") # now in modal
      expect(page).to have_text "Thank you for your interest"

      # by saving and restoring from cookie, the form should be pre-filled
      visit oral_history_request_form_path(work2.friendlier_id)
      expect(find("#{pr}patron_name").value).to eq patron_name
      expect(find("#{pr}oral_history_requester").value).to eq patron_email
      expect(find("#{pr}patron_institution").value).to eq patron_institution
      expect(find("#{pr}intended_use").value).to eq intended_use
    end

  end

end
