require 'rails_helper'

describe DownloadFilenameHelper, type: :model do
  describe "#first_three_words" do
    it "extracts first three words" do
      expect(DownloadFilenameHelper.first_three_words("one two three four five")).to eq("one_two_three")
    end

    it "collapses spaces" do
      expect(DownloadFilenameHelper.first_three_words("one    two   three four five")).to eq("one_two_three")
    end

    it "strips punctuation" do
      expect(DownloadFilenameHelper.first_three_words("one:two: three four five")).to eq("one_two_three")
    end

    it "erases single quotes" do
      expect(DownloadFilenameHelper.first_three_words("jonathan's very fine code")).to eq("jonathans_very_fine")
    end

    it "ignores filename suffix" do
      expect(DownloadFilenameHelper.first_three_words("one.jpg")).to eq("one")
    end

    it "downcases" do
      expect(DownloadFilenameHelper.first_three_words("one:two: three four five")).to eq("one_two_three")
    end

    it "limits to 25 characters total" do
      expect(DownloadFilenameHelper.first_three_words("0123456789 0123'456789     0123456789")).to eq("0123456789_0123456789_012")
    end
  end

  describe "#filename_with_suffix" do
    it "replaces existing suffix" do
      expect(DownloadFilenameHelper.filename_with_suffix("filename.pdf", content_type: "image/jpeg")).to eq("filename.jpeg")
    end

    it "can look up content_type" do
      expect(DownloadFilenameHelper.filename_with_suffix("filename", content_type: "image/jpeg")).to eq("filename.jpeg")
    end

    it "has no suffix for unrecognized content_type" do
      expect(DownloadFilenameHelper.filename_with_suffix("filename", content_type: "image/made-this-up")).to eq("filename")
    end

    it "removes existing suffix for unrecognized content type" do
      expect(DownloadFilenameHelper.filename_with_suffix("filename.pdf", content_type: "image/made-this-up")).to eq("filename")
    end

    it "removes dangerous characters" do
      expect(DownloadFilenameHelper.filename_with_suffix("this/has dangerous:characters/", content_type: "image/jpeg")).to eq("thishas dangerouscharacters.jpeg")
    end
  end

  describe "#filename_base_from_parent" do
    let(:asset) { create(:asset, position: 12, parent: create(:work, title: "Plastics make the package Dow makes the plastics"))}

    it "creates a long filename base" do
      expect(DownloadFilenameHelper.filename_base_from_parent(asset)).to eq "plastics_make_the_#{asset.parent.friendlier_id}_#{asset.position}_#{asset.friendlier_id}"
    end

    describe "with missing parent and position" do
      let(:asset) { create(:asset, title: "Plastics make the package Dow makes the plastics")}
      it "does it's best" do
        # this shoudln't happen, but we don't want to error
        expect(DownloadFilenameHelper.filename_base_from_parent(asset)).to eq asset.friendlier_id
      end
    end
  end

  describe "#filename_for_asset" do
    let(:derivative_key) { :thumb_mini }
    let(:asset) do
      create(:asset_with_faked_file,
             faked_derivatives: [ build(:faked_derivative, key: derivative_key, uploaded_file: build(:stored_uploaded_file, content_type: "image/jpeg")) ],
             position: 12,
             parent: create(:work, title: "Plastics make the package Dow makes the plastics"))
    end
    let(:derivative) { asset.derivative_for(derivative_key) }
    it "can create for original" do
      expect(DownloadFilenameHelper.filename_for_asset(asset)).to eq "plastics_make_the_#{asset.parent.friendlier_id}_12_#{asset.friendlier_id}.png"
    end

    it "can create for derivative" do
      # note ends with jpeg, not png, cause it's a jpeg derivative
      expect(DownloadFilenameHelper.filename_for_asset(asset, derivative: derivative)).to eq "plastics_make_the_#{asset.parent.friendlier_id}_12_#{asset.friendlier_id}_#{derivative.key}.jpeg"
    end
  end

end
