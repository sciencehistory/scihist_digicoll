require 'rails_helper'

describe "legacy original download links redirect" do
  let(:asset) {  create(:asset_with_faked_file, :pdf) }

  it "redirects" do
    get("/downloads/#{asset.friendlier_id}")
    expect(response).to redirect_to(download_path(asset.file_category, asset))
  end
end
