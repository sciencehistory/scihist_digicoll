require 'rails_helper'

describe "work factory" do
  describe "published work" do
    let(:work) { build(:work, :published) }

    it "is valid" do
      expect(work).to be_valid
    end

    it "is published" do
      expect(work).to be_published
    end

    it "creates with representative" do
      expect(work.representative).to be_present
    end
  end

  describe "oral history work" do
    describe "published oral history work" do
      let(:work) { build(:oral_history_work, :published) }

      it "is genre oral history" do
        expect(work.genre).to eq ["Oral histories"]
      end

      it "is valid" do
        expect(work).to be_valid
      end

      it "is published" do
        expect(work).to be_published
      end

      it "has representative" do
        expect(work.representative).to be_present
      end
    end
  end

  describe "video work" do
    describe "published video work" do
      let(:work) { build(:video, :published) }

      it "is valid" do
        expect(work).to be_valid
      end

      it "is published" do
        expect(work).to be_published
      end

      it "has representative" do
        expect(work.representative).to be_present
      end

      it "has the correct format" do
        expect(work.format).to eq(["moving_image"])
      end

      it "has an attached video with the proper mime type" do
        expect(work.representative.file_data['storage']).to eq("store")
        expect(work.representative.file_data['metadata']['mime_type']).to eq("video/mp4")
      end
    end
  end
end
