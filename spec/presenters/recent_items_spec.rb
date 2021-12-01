require 'rails_helper'
describe RecentItems, type: :model do
  let(:bag) do
    RecentItems.new(
      how_many_works_to_show: 2,
      how_many_works_in_bag: 10).fetch_bag
  end
  # Evaluating (for instance) 2.days.ago
  # repeatedly yields different results.
  let(:days_ago) { (1..6).to_a.map { |i| i.days.ago } }
  let!(:works) do
    [
      create(:public_work).tap do |w|
        w.title = "published_at old"
        w.published_at = days_ago[5]
        w.updated_at   = days_ago[5]
        w.save(validate:false)
      end,
      create(:public_work).tap do |w|
        w.title = "published_at medium"
        w.published_at = days_ago[4]
        w.updated_at   = days_ago[4]
        w.save(validate:false)
      end,
      create(:public_work).tap do |w|
        w.title = "published_at new, updated_at older"
        w.published_at = days_ago[3]
        w.updated_at   = days_ago[3]
        w.save(validate:false)
      end,
      create(:public_work).tap do |w|
        w.title = "published_at new, updated_at newer"
        w.published_at = days_ago[3]
        w.updated_at   = days_ago[2]
        w.save(validate:false)
      end,
      create(:public_work).tap do |w|
        w.title = "published_at nil, updated_at older"
        w.published_at = nil
        w.updated_at   = days_ago[2]
        w.save(validate:false)
      end,
      create(:public_work).tap do |w|
        w.title = "published_at nil, updated_at newer"
        w.published_at = nil
        w.updated_at   = days_ago[1]
        w.save(validate:false)
      end
    ]
  end
  it "sorts nil values after dates; breaks ties between published_at using updated_at" do
    expect(bag.map(&:title)).to eq [
      "published_at new, updated_at newer",
      "published_at new, updated_at older",
      "published_at medium",
      "published_at old",
      "published_at nil, updated_at newer",
      "published_at nil, updated_at older"
    ]
  end
end