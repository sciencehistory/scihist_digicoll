require 'rails_helper'

describe "url contains a null byte" do
  it "responds with 422" do
    get "/works/bla%00bla"
    expect(response.code).to eq("302")
    expect(response).to redirect_to("/422")
  end
end
