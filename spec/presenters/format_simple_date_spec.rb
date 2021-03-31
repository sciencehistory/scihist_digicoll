require 'rails_helper'

describe FormatSimpleDate do


  describe "nil input" do
    it "returns empty string" do
      expect(FormatSimpleDate.new(nil).display).to eq("")
    end
  end

  describe "bad input" do
    it "returns emtpy string" do
      expect(FormatSimpleDate.new("mis-formatted").display).to eq("")
    end
  end

  describe "year only" do
    it "returns year" do
      expect(FormatSimpleDate.new("1975").display).to eq("1975")
    end
  end

  describe "year and month" do
    it "formats" do
      expect(FormatSimpleDate.new("1975-06").display).to eq("June 1975")
    end
  end

  describe "year month date" do
    it "formats" do
      expect(FormatSimpleDate.new("1975-11-05").display).to eq("November 05, 1975")
    end
  end

  describe "date range" do
    it "formats as range" do
      expect(FormatSimpleDate.new("1975-06", "1980").display).to eq("June 1975 to 1980")
    end
  end

  describe "start and end are identical" do
    it "does not format as a range" do
      expect(FormatSimpleDate.new("1947", "1947").display).to eq("1947")
    end
  end

end
