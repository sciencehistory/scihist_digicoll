require 'rails_helper'

describe "legacy original download links redirect" do
  let(:asset) {  create(:asset_with_faked_file, :pdf) }

  it "redirects original" do
    get("/downloads/#{asset.friendlier_id}")
    expect(response).to redirect_to(download_path(asset.file_category, asset))
    expect(response).to have_http_status(301)
  end

  it "redirects derivative" do
    get("/downloads/#{asset.friendlier_id}/thumb_small")
    expect(response).to redirect_to(download_derivative_path(asset, "thumb_small"))
    expect(response).to have_http_status(301)
  end

  it "redirects derivative keeping any query params" do
    get("/downloads/#{asset.friendlier_id}/thumb_small?disposition=inline")
    expect(response).to redirect_to(download_derivative_path(asset, "thumb_small", disposition: "inline"))
    expect(response).to have_http_status(301)
  end
end
