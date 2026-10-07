require 'rails_helper'

describe WorkCountReport do
  let(:today) { Date.new(2026, 10, 7) }
  let(:report) { WorkCountReport.new(today: today) }

  # [created_total, created_current, published_total, published_current]
  def counts_for(month)
    [month.created_total, month.created_current, month.published_total, month.published_current]
  end

  it "covers the six full months before the current one, oldest first" do
    expect(report.months_with_counts.map(&:starts_on)).to eq [4, 5, 6, 7, 8, 9].map { |m| Date.new(2026, m, 1) }
  end

  it "returns zeros with no works" do
    expect(counts_for(report.months_with_counts.last)).to eq [0, 0, 0, 0]
  end

  describe "with works" do
    before do
      create(:work, created_at: Time.zone.local(2026, 3, 31, 23, 59), published_at: nil)       # before window, counts in totals
      create(:work, created_at: Time.zone.local(2026, 8, 1, 0, 0),    published_at: Time.zone.local(2026, 8, 31, 23, 59, 59))
      create(:work, created_at: Time.zone.local(2026, 8, 20),         published_at: Time.zone.local(2026, 9, 1, 0, 0))
      create(:work, created_at: Time.zone.local(2026, 10, 2),         published_at: Time.zone.local(2026, 10, 3)) # current month: excluded
      # published before we tracked published_at; earliest known published_at is 2026-08-31
      # (kithe sets published_at on save, so clear it afterwards)
      create_list(:work, 2, :published, created_at: Time.zone.local(2026, 2, 1)).each { |w| w.update_column(:published_at, nil) }
    end

    it "counts cumulative totals and per-month values" do
      months = report.months_with_counts.index_by { |month| month.starts_on.month }

      expect(counts_for(months[4])).to eq [3, 0, 0, 0]
      expect(counts_for(months[7])).to eq [3, 0, 0, 0]
      # undated published works count only from the month containing the earliest published_at
      expect(counts_for(months[8])).to eq [5, 2, 3, 1]
      expect(counts_for(months[9])).to eq [5, 0, 4, 1]
    end
  end
end
