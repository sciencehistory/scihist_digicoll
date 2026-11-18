require "rails_helper"

describe "Bot challenge on patron pages", type: :request do
  let(:patron) { create(:patron) }

  around do |example|
    orig_config = BotChallengePage::BotChallengePageController.bot_challenge_config.dup
    BotChallengePage::BotChallengePageController.bot_challenge_config.enabled = true
    example.run
  ensure
    BotChallengePage::BotChallengePageController.bot_challenge_config = orig_config
  end

  def expect_challenged
    expect(response).to have_http_status(403)
    expect(response.body).to include("bot_challenge_page")
  end

  describe "work show page" do
    let(:availability_mode) { :automatic_request }
    let(:work) { create(:oral_history_work, :available_by_request, published: true, availability_mode: availability_mode) }

    it "challenges patron who can see by-request content" do
      sign_in patron
      get work_path(work.friendlier_id)
      expect_challenged
    end

    it "does not challenge anonymous visitor who is only seeing cover page" do
      get work_path(work.friendlier_id)
      expect(response).to have_http_status(200)
    end

    it "does not challenge patron without access who is only seeing cover page" do
      sign_in create(:patron, :unconfirmed)
      get work_path(work.friendlier_id)
      expect(response).to have_http_status(200)
    end

    describe "direct oral history" do
      let(:availability_mode) { :direct }

      it "does not challenge patron" do
        sign_in patron
        get work_path(work.friendlier_id)
        expect(response).to have_http_status(200)
      end
    end
  end

  describe "request show page" do
    let(:oh_request) { create(:oral_history_request, patron: patron, delivery_status: "approved") }

    before { sign_in patron }

    it "challenges request page" do
      get oral_history_request_path(oh_request)
      expect_challenged
    end
  end
end
