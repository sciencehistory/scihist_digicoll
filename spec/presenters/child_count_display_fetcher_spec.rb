require 'rails_helper'

describe ChildCountDisplayFetcher do
  let(:items) { [item] } # override if you want more than one
  let(:item_counter) { ChildCountDisplayFetcher.new(items.collect(&:friendlier_id)) }

  describe "for Works" do
    describe "with published items" do
      let(:item) { create(:work, members: [create(:work), create(:work)]) }

      it "fetches member count" do
        expect(item_counter.member_count_for_friendlier_id(item.friendlier_id)).to eq(2)
        expect(item_counter.display_count_for(item)).to eq(2)
      end
    end

    describe "for unpublished work members" do
      let(:item) { create(:work, members: [create(:work), create(:work, published: false)]) }

      it "does not include unpublished members" do
        expect(item_counter.member_count_for_friendlier_id(item.friendlier_id)).to eq(1)
        expect(item_counter.display_count_for(item)).to eq(1)
      end
    end

    describe "with no members" do
      let(:item) { create(:work) }

      it "returns zero" do
        expect(item_counter.member_count_for_friendlier_id(item.friendlier_id)).to eq(0)
        expect(item_counter.display_count_for(item)).to eq(0)
      end
    end

    describe "for multiple works in batch" do
      # force initial creation outside of our db query count expectation
      # with let! (exclamation point). Also force fetch of friendlier_id
      # from db!
      let!(:items) {
        [
          create(:work, members: [create(:work)]),
          create(:work, members: [create(:work)]),
          create(:work, members: [create(:work)]),
        ].tap do |arr|
          arr.each(&:friendlier_id)
        end
      }

      it "makes only one DB query" do
        expect {
          item_counter.display_count_for(items.first)
          item_counter.display_count_for(items.second)
          item_counter.display_count_for(items.third)
        }.to make_database_queries(count: 1)
      end
    end
  end

  describe "for Collections" do
    describe "with published items" do
      let(:item) { create(:collection, contains: [create(:work), create(:work)]) }

      it "fetches contains count" do
        expect(item_counter.contains_count_for_friendlier_id(item.friendlier_id)).to eq(2)
        expect(item_counter.display_count_for(item)).to eq(2)
      end
    end

    describe "for unpublished work members" do
      let(:item) { create(:collection, contains: [create(:work), create(:work, published: false)]) }

      it "does not include unpublished contained" do
        expect(item_counter.contains_count_for_friendlier_id(item.friendlier_id)).to eq(1)
        expect(item_counter.display_count_for(item)).to eq(1)
      end
    end

    describe "with no contained" do
      let(:item) { create(:collection) }

      it "returns zero" do
        expect(item_counter.contains_count_for_friendlier_id(item.friendlier_id)).to eq(0)
        expect(item_counter.display_count_for(item)).to eq(0)
      end
    end

    describe "for multiple collections in batch" do
      # force initial creation outside of our db query count expectation
      # with let! (exclamation point). Also force fetch of friendlier_id
      # from db!
      let!(:items) {
        [
          create(:collection, contains: [create(:work)]),
          create(:collection, contains: [create(:work)]),
          create(:collection, contains: [create(:work)]),
        ].tap do |arr|
          arr.each(&:friendlier_id)
        end
      }

      it "makes only one DB query" do
        expect {
          item_counter.display_count_for(items.first)
          item_counter.display_count_for(items.second)
          item_counter.display_count_for(items.third)
        }.to make_database_queries(count: 1)
      end
    end
  end

  describe "for friendlier_id not in batch" do
    let(:item) { create(:work) }
    let(:other_work) { create(:work) }

    it "raises ArgumentError when requested" do
      expect {
        item_counter.display_count_for(other_work)
      }.to raise_error(ArgumentError)

      expect {
        item_counter.member_count_for_friendlier_id(other_work.friendlier_id)
      }.to raise_error(ArgumentError)

      expect {
        item_counter.contains_count_for_friendlier_id(other_work.friendlier_id)
      }.to raise_error(ArgumentError)

      expect {
        item_counter.member_count_for_friendlier_id("non-existing_friendlier_id")
      }.to raise_error(ArgumentError)
    end
  end
end
