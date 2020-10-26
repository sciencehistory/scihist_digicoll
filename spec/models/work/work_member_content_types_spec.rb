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

  describe "mode: :association" do
    describe "pre-loaded" do
      let(:preloaded_work) { Work.where(id: work.id).includes(members: :leaf_representative).first }
      it "finds" do
        expect(preloaded_work.member_content_types(mode: :association)).to match_array(["image/tiff", "application/pdf", "audio/mpeg"])
      end
    end

    describe "none pre-loaded" do
      let(:not_preloaded_work) { Work.where(id: work.id).first }

      it "raises" do
        expect {
          not_preloaded_work.member_content_types(mode: :association)
        }.to raise_error(TypeError)
      end
    end

    describe "partially pre-loaded" do
      let(:partially_preloaded_work) { Work.where(id: work.id).includes(:members).first }

      it "raises" do
        expect {
          partially_preloaded_work.member_content_types(mode: :association)
        }.to raise_error(TypeError)
      end
    end
  end

  describe "mode: :query" do
    it "finds" do
      expect(work.member_content_types(mode: :query)).to match_array(["image/tiff", "application/pdf", "audio/mpeg"])
    end
  end
end
