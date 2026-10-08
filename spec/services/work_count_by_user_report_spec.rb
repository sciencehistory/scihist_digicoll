require 'rails_helper'

describe WorkCountByUserReport do
  let(:report) { WorkCountByUserReport.new(from_month: Date.new(2026, 8, 15), to_month: Date.new(2026, 10, 2)) }
  let!(:alice) { create(:user, email: "alice@example.org", name: "Alice Smith") }
  let!(:bob)   { create(:user, email: "bob@example.org", name: nil) }

  def row_values(rows)
    rows.map { |r| [r.month.month, r.account, r.created_count, r.published_count] }
  end

  def publish_by(work, user)
    work.update_columns(last_published_by_id: user&.id)
  end

  it "has [ALL] rows of zeros for months with no works" do
    expect(row_values(report.rows)).to eq [
      [8, "[ALL]", 0, 0], [9, "[ALL]", 0, 0], [10, "[ALL]", 0, 0]
    ]
  end

  it "includes the last moment of the to_month and excludes the first moment after it" do
    create(:work, created_by: alice, created_at: Time.zone.local(2026, 10, 31, 23, 59, 59.999999))
    create(:work, created_by: alice, created_at: Time.zone.local(2026, 11, 1, 0, 0))

    expect(row_values(report.rows)).to include([10, "[ALL]", 1, 0])
    expect(report.rows.map { |r| r.month.month }.uniq).to eq [8, 9, 10]
  end

  describe "with works" do
    before do
      create(:work, created_by: alice, created_at: Time.zone.local(2026, 9, 1, 0, 0))
      create(:work, created_by: alice, created_at: Time.zone.local(2026, 9, 30, 23, 59))
      create(:work, created_by: bob,   created_at: Time.zone.local(2026, 9, 10))
      create(:work, created_by: nil,   created_at: Time.zone.local(2026, 9, 11))
      create(:work, created_by: alice, created_at: Time.zone.local(2026, 7, 31, 23, 59)) # out of range

      publish_by(create(:work, created_by: alice, created_at: Time.zone.local(2026, 8, 3),
                        published_at: Time.zone.local(2026, 9, 2)), alice)
      publish_by(create(:work, created_by: alice, created_at: Time.zone.local(2026, 8, 4),
                        published_at: Time.zone.local(2026, 9, 3)), nil)
    end

    it "breaks down by account, with [ALL] first, then {UNRECORDED}, then names" do
      sept = row_values(report.rows).select { |month, *| month == 9 }

      expect(sept).to eq [
        [9, "[ALL]",             4, 2],
        [9, "{UNRECORDED}",      1, 1],
        [9, "Alice Smith",       2, 1],
        [9, "bob@example.org",   1, 0]
      ]
    end

    it "lists oldest month first and includes accounts that only created or published" do
      aug = row_values(report.rows).select { |month, *| month == 8 }

      expect(row_values(report.rows).map(&:first).uniq).to eq [8, 9, 10]
      expect(aug).to eq [[8, "[ALL]", 2, 0], [8, "Alice Smith", 2, 0]]
    end
  end
end
