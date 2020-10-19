require 'rails_helper'

# in a separate spec file because we likely want to extract to kithe
describe "Work#member_content_types" do
  let(:work) do
    create(:work, members: [
      create(:asset_with_faked_file, faked_content_type: "image/tiff"),
      create(:asset_with_faked_file, faked_content_type: "application/pdf"),
      create(:work, members: [create(:asset_with_faked_file, faked_content_type: "audio/mpeg")]),
      create(:work, members: [create(:asset_with_faked_file, faked_content_type: "image/tiff")]),
    ])
  end

  it "finds" do
    expect(work.member_content_types).to match(["image/tiff", "application/pdf", "audio/mpeg"])
  end
end
