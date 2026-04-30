require 'rails_helper'

describe GoogleArtsAndCultureDownloadCreatorJob do

  let(:user) {FactoryBot.create(:admin_user)}

  let(:work_1) { FactoryBot.build(:public_work, :with_assets, creator_attributes: {'0': {"category"=> "artist", "value"=>"artist" } } )}
  let(:work_2) { FactoryBot.build(:public_work, :with_assets)}
  let(:work_3) { FactoryBot.build(:public_work, :with_assets)}

  let(:work_4) { FactoryBot.build(:public_work)}
  let(:work_5) { FactoryBot.build(:public_work)}
  let(:work_6) { FactoryBot.build(:public_work)}


  let(:job) { GoogleArtsAndCultureDownloadCreatorJob.new(user:user, user_notes: "some notes") }

  let(:error_class) { StandardError }


  before do
    user.works_in_cart = [work_1, work_2, work_3, work_4, work_5, work_6]
  end

  it "creates an export" do
    expect(user.google_arts_and_culture_downloads.count).to eq 0
    job.perform_now
    expect(user.google_arts_and_culture_downloads.count).to eq 1
    download = user.google_arts_and_culture_downloads.first
    expect(download.status).to eq "success"
    expect(download.progress).to eq 6
    expect(download.progress_total).to eq 6
    expect(download.user_notes).to eq "some notes"
  end

  it "fails quietly if cart is empty without creating a download." do
    user.update!({works_in_cart: []})
    expect(user.google_arts_and_culture_downloads.count).to eq 0
    job.perform_now
    expect(user.google_arts_and_culture_downloads.count).to eq 0
  end


  describe "with an error" do
    before do
      expect(job).to receive(:add_metadata_and_files_to_zip).and_raise(error_class)
    end
    it "finishes in error state, and raises original" do
      expect(user.google_arts_and_culture_downloads.count).to eq 0
      expect {
        job.perform_now
      }.to raise_error(error_class)
      expect(user.google_arts_and_culture_downloads.count).to eq 1
      download = user.google_arts_and_culture_downloads.first
      expect(download.status).to eq "error"
      expect(download.progress).to eq 0
      expect(download.progress_total).to eq 6
      expect(download.user_notes).to eq "some notes"
      expect(download.error_info).to eq ("StandardError")
    end
  end
end
