require 'rails_helper'

describe OralHistoryContent::DateAndPlace do
  describe "#to_s" do
    describe "USA" do
      let(:date_and_place) do
        OralHistoryContent::DateAndPlace.new(
          date: "1923",
          city: "Place of Birth",
          state: "CA",
          country: "US"
        )
      end

      it "correctly formats" do
        expect(date_and_place.to_s).to eq("1923, Place of Birth, California, United States")
      end
    end

    describe "Canada" do
      let(:date_and_place) do
        OralHistoryContent::DateAndPlace.new(
          date: "2223",
          city: "Place of Death",
          province: "NU",
          country: "CA"
        )
      end

      it "correctly formats" do
        expect(date_and_place.to_s).to eq("2223, Place of Death, Nunavut, Canada")
      end
    end
  end
end
