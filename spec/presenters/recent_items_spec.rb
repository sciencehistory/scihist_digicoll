require 'rails_helper'
describe RecentItems, type: :model do
  describe "correctly picks most recently updated" do
    let(:bag) { RecentItems.new(how_many_works_to_show: 2, how_many_works_in_bag: 10).fetch_bag }
    let(:published_at) {
      midnight = Time.now.to_date.to_time
      [nil] * 5 + [midnight] * 5
    }
    let!(:works) { 
      (1..10).to_a.map do |i|
        create(:public_work, title: i).tap do |w|
          w.published_at = published_at[i]
          w.updated_at   = i.days.ago
          w.save(validate:false)
        end
      end
    }

    describe "Works with nil published date" do
      it "sorts nil values after dates" do
        midnight = Time.now.to_date.to_time
        expect(bag.map(&:published_at)).to eq [midnight] * 5 + [nil] * 5
      end
    end

    describe "identical published_at dates" do
      let(:published_at_midnight) {
        midnight = Time.now.to_date.to_time
        published_at_midnight = bag.select{|w| w.published_at == midnight}  
      }
      it "are sorted by reverse cron updated_at" do
        should_be_reverse_cron = published_at_midnight.
          map(&:updated_at)
        reverse_cron = should_be_reverse_cron.dup.
          sort.reverse
        expect(should_be_reverse_cron).to eq reverse_cron
      end
    end
  end
end