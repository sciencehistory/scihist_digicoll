require 'rails_helper'

describe GoogleArtsAndCultureDownload do
  let(:download) { create(:admin_user).google_arts_and_culture_downloads.create!({ user_notes: @user_notes, progress: 0, progress_total: 3 }) }
  let(:file) {  Tempfile.new(["files", ".zip"]) }
  it "can put and access file" do
    download.put_file(file)
    expect(download.file_exists?).to be true
    expect(download.file_url).to match /public\/google_arts_and_culture_downloads\/google_arts_and_culture_downloads_[\d]+\.zip/
    download.log_work_added!
  end
end
