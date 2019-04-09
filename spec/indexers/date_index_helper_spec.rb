require 'rails_helper'

RSpec.describe DateIndexHelper do
  let(:work) { FactoryBot.build(:work, date_of_work: date_of_work ) }
  let(:generator) { DateIndexHelper.new(work) }
  # individual cases have to define `date_values` with `let`
  let(:index_values) { generator.expanded_years }

  describe "no dates" do
    let(:date_of_work) { [Work::DateOfWork.new] }
    it "has no index dates" do
      expect(index_values).to eq([])
    end
  end

  describe "Undated" do
    let(:date_of_work) { [ Work::DateOfWork.new(start_qualifier: "Undated") ] }
    it "has no index dates" do
      expect(index_values).to eq([])
    end
  end

  describe "decade" do
    let(:decade) { 1910 }
    let(:date_of_work) { [ Work::DateOfWork.new(start: decade.to_s, start_qualifier: "decade") ] }
    it "has whole decade" do
      expect(index_values).to eq( (decade..(decade+9)).to_a )
    end
  end

  describe "century" do
    let(:century) { 1800 }
    let(:date_of_work) { [ Work::DateOfWork.new(start: century.to_s, start_qualifier: "century") ] }
    it "has whole century" do
      expect(index_values).to eq( (century..(century+99)).to_a )
    end
  end

  describe "bare start date" do
    let(:date_of_work) { [ Work::DateOfWork.new(start: "1955-05-12") ] }
    it "has single year" do
      expect(index_values).to eq( [1955] )
    end
  end

  describe "start and end date" do
    let(:start_year) { 1954}
    let(:end_year) { 2001 }
    let(:date_of_work) { [ Work::DateOfWork.new(start: start_year.to_s, start_qualifier: "circa", finish: end_year.to_s, finish_qualifier: "circa") ] }
    it "has the range" do
      expect(index_values).to eq( (start_year..end_year).to_a )
    end
  end

  describe "multiple dates" do
    let(:date_of_work) { [ Work::DateOfWork.new(start: "1905"), Work::DateOfWork.new(start: "1910", finish: "1912") ] }
    it "has all dates" do
      expect(index_values).to match_array( (1910..1912).to_a + [1905] )
    end
  end

  describe "weird cases" do
    describe "finish before start" do
      let(:start_year) { 1954}
      let(:date_of_work) { [ Work::DateOfWork.new(start: start_year.to_s, finish: (start_year-10).to_s) ] }
      it "has only start_year" do
        expect(index_values).to eq( [start_year] )
      end
    end
    describe "finish but no start" do
      let(:date_of_work) { [ Work::DateOfWork.new(finish: "1910") ] }
      it "has no date" do
        expect(index_values).to eq( [] )
      end
    end
    describe "non-date data" do
      let(:date_of_work) { [ Work::DateOfWork.new(start: "this ain't right") ] }
      it "has no date" do
        expect(index_values).to eq( [] )
      end
    end
  end

end
