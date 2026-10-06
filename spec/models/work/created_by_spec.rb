require 'rails_helper'

describe Work, "created_by" do
  let(:user) { create(:user) }
  after { Current.reset }

  it "is set from Current.user on create" do
    Current.user = user
    expect(create(:work).created_by).to eq user
  end

  it "is nil when there is no Current.user" do
    expect(create(:work).created_by).to be_nil
  end

  it "does not override an explicitly assigned value" do
    Current.user = create(:user, email: "other@example.com")
    expect(create(:work, created_by: user).created_by).to eq user
  end
end
