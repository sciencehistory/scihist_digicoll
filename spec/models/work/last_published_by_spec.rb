require 'rails_helper'

describe Work, "last_published_by" do
  let(:user) { create(:user) }
  after { Current.reset }

  it "is set from Current.user when published" do
    work = create(:work, :with_complete_metadata)
    Current.user = user
    work.update!(published: true)
    expect(work.last_published_by).to eq user
  end
end
