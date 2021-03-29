require 'rails_helper'

describe OralHistoryBiographicalDisplay do
  let(:presenter) { OralHistoryBiographicalDisplay.new(work)}

  describe "an empty work" do
    let(:work) { create(:work, genre: ["Oral histories"])}

    it "has empty results" do
      expect(presenter.schools).to eq([])
      expect(presenter.honors).to eq([])
      expect(presenter.grouped_jobs).to eq({})
    end
  end

  describe "#grouped_jobs" do
    let(:work) do
      create(:oral_history_work).tap do |work|
        work.oral_history_content.interviewee_job = [
          {start: "1930", end: "1940", institution: 'Two University',  role: 'Professor'},
          {start: "1915", end: "1920", institution: 'One University',  role: 'Fellow'},
          {start: "1920", end: "1930", institution: 'Two University',  role: 'Executive'},
          {start: "1910", end: "1930", institution: 'One University',  role: 'Assistant'}
        ]
      end
    end

    it "groups and sorts" do
      # One Univeristy comes first, cause it has the earliest date
      expect(presenter.grouped_jobs.keys).to eq(["One University", "Two University"])
      expect(presenter.grouped_jobs["One University"].collect(&:start)).to eq(["1910", "1915"])
      expect(presenter.grouped_jobs["Two University"].collect(&:start)).to eq(["1920", "1930"])
    end
  end

end
