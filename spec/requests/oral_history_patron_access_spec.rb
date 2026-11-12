require "rails_helper"

describe "Oral history work page for patrons", type: :request do
  let(:availability_mode) { :automatic_request }
  let(:work) { create(:oral_history_work, :available_by_request, published: true, availability_mode: availability_mode) }
  let(:patron) { create(:patron) }
  let(:by_request_ids) { work.members.reject(&:published?).map(&:friendlier_id) }

  def page
    Nokogiri::HTML(response.body)
  end

  def expect_audio_page_with_by_request_files
    expect(page.at_css(".work-show-audio")).to be_present
    expect(page.at_css("[data-role='registered-patron-access']")).to be_present
    by_request_ids.each { |id| expect(response.body).to include(id) }
    expect(page.css(".badge").map(&:text)).not_to include("Private")
  end

  def expect_file_list_page
    expect(page.at_css(".work-show-file-list")).to be_present
    expect(page.at_css("[data-role='registered-patron-access']")).not_to be_present
    by_request_ids.each { |id| expect(response.body).not_to include(id) }
  end

  it "shows audio page with by-request files to confirmed patron" do
    sign_in patron
    get work_path(work.friendlier_id)
    expect_audio_page_with_by_request_files
  end

  it "shows file list to anonymous visitor" do
    get work_path(work.friendlier_id)
    expect_file_list_page
  end

  it "shows file list to unconfirmed patron" do
    patron.update!(confirmed_at: nil)
    sign_in patron
    get work_path(work.friendlier_id)
    expect_file_list_page
  end

  describe "direct, with by-request flagged files" do
    let(:availability_mode) { :direct }

    it "does not show unpublished files to confirmed patron" do
      sign_in patron
      get work_path(work.friendlier_id)
      expect(page.at_css("[data-role='registered-patron-access']")).not_to be_present
      by_request_ids.each { |id| expect(response.body).not_to include(id) }
    end
  end

  describe "reviewed_request" do
    let(:availability_mode) { :reviewed_request }

    it "shows file list to patron with no request" do
      sign_in patron
      get work_path(work.friendlier_id)
      expect_file_list_page
    end

    it "shows audio page to patron with approved request" do
      create(:oral_history_request, patron: patron, work: work, delivery_status: "approved")
      sign_in patron
      get work_path(work.friendlier_id)
      expect_audio_page_with_by_request_files
    end
  end
end
