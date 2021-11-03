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
end
