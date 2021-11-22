require 'rails_helper'

describe "published_at" do   
  let(:work) do
    create(:work, :published, published: false, published_at: false)
  end
  it "sets published_at when a work is published" do
    work.update(published: true)
    expect(work.published_at).to be_within(1.second).of Time.now
  end
end