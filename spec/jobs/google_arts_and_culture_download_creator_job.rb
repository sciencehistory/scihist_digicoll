require 'rails_helper'

# DBQueryMatchers.configure do |config|
#   config.schemaless = true
# end

describe GoogleArtsAndCultureDownloadCreatorJob do

  let(:user) {FactoryBot.create(:admin_user)}

  let(:work_1) { FactoryBot.build(:public_work, :with_assets)}
  let(:work_2) { FactoryBot.build(:public_work, :with_assets)}
  let(:work_3) { FactoryBot.build(:public_work, :with_assets)}

  let(:work_4) { FactoryBot.build(:public_work)}
  let(:work_5) { FactoryBot.build(:public_work)}
  let(:work_6) { FactoryBot.build(:public_work)}

  #let(:works_in_cart) {controller.current_user.works_in_cart.to_a}

  before do
    user.works_in_cart = [work_1, work_2, work_3, work_4, work_5, work_6]
  end


  it "creates an export" do
    GoogleArtsAndCultureDownloadCreatorJob.new(user:user).perform_now
    pp user.google_arts_and_culture_downloads.first

    #expect(WebMock).to have_requested(:post, solr_update_url_regex).once
  end

  # it "skips missing IDs without error" do
  #   ReindexWorksJob.new([SecureRandom.uuid, SecureRandom.uuid]).perform_now

  #   expect(WebMock).not_to have_requested(:post, solr_update_url_regex)
  # end
end
