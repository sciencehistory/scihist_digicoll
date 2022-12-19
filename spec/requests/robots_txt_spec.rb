require 'rails_helper'

describe "robots.txt" do
  it "is routable" do
    get "/robots.txt"
    expect(response.code).to eq("200")
  end
end
