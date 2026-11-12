require "rails_helper"

# Which page an OH gets: audio player or file list. See WorksController#can_see_audio_player?
describe "Oral history work page type", type: :request do
  let(:published_audio) { build(:asset_with_faked_file, :mp3, published: true, faked_derivatives: {}) }
  let(:unpublished_audio) { build(:asset_with_faked_file, :mp3, published: false, faked_derivatives: {}) }
  let(:work) { create(:oral_history_work, published: true, members: members) }

  def page
    Nokogiri::HTML(response.body)
  end

  def expect_audio_page
    expect(page.at_css(".work-show-audio")).to be_present
  end

  def expect_file_list_page
    expect(page.at_css(".work-show-file-list")).to be_present
  end

  describe "direct, with published audio" do
    let(:members) { [published_audio] }

    it "shows audio page to anonymous visitor" do
      get work_path(work.friendlier_id)
      expect_audio_page
    end
  end

  describe "direct, with only unpublished audio" do
    let(:members) { [unpublished_audio] }

    it "shows file list to anonymous visitor" do
      get work_path(work.friendlier_id)
      expect_file_list_page
    end

    it "shows staff the same file list as the public" do
      sign_in create(:admin_user)
      get work_path(work.friendlier_id)
      expect_file_list_page
    end
  end

  describe "embargoed, even with published audio" do
    let(:members) { [published_audio] }
    before { work.oral_history_content!.update!(availability_mode: :embargoed) }

    it "shows file list to anonymous visitor" do
      get work_path(work.friendlier_id)
      expect_file_list_page
    end

    it "shows file list to confirmed patron" do
      sign_in create(:patron)
      get work_path(work.friendlier_id)
      expect_file_list_page
    end
  end
end
