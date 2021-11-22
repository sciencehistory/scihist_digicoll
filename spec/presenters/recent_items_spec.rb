require 'rails_helper'
describe RecentItems, type: :model do
  describe "correctly picks most recently updated" do
    let(:bag) { RecentItems.new(how_many_works_to_show: 2, how_many_works_in_bag: 10).fetch_bag }
    describe "Works with nil published date" do
      let!(:works) { 
        (1..10).to_a.map do |i|
          midnight = Time.now.to_date.to_time
          create(:public_work, title: i).tap do |w|
            w.published_at = [midnight] * 5 + [nil] * 5
            w.updated_at   = i.days.ago
            w.save(validate:false)
          end
        end
      }
      it "are correctly sorted" do
        expect(bag.map(&:title)).to eq (1..10).map(&:to_s)
      end
    end
  end
end