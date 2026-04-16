require 'rails_helper'

describe GoogleArtsAndCultureDownload do
  let(:download) { create(:admin_user).google_arts_and_culture_downloads.create!({ user_notes: @user_notes, progress: 0, progress_total: 3 }) }
  let(:file) {  Tempfile.new(["files", ".zip"]) }
  it "can put and access file" do
    download.put_file(file)

    shrine_info = download.file_data
    expect(shrine_info['id']).to match /google_arts_and_culture_downloads_\d*.zip/
    expect(shrine_info['storage']).to eq "google_arts_and_culture"
    expect(shrine_info['metadata']['mime_type']).to eq "application/zip"
    expect(shrine_info['metadata'].keys.sort).to eq ["created_at", "created_by", "mime_type"]
    expect(download.file_url).to match /public\/google_arts_and_culture_downloads\/google_arts_and_culture_downloads_[\d]+\.zip/

    download.log_work_added!
    expect(download.works_added).to eq 1

  end
end
