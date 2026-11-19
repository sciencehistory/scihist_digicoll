require "rails_helper"

describe Work do
  let(:availability_mode) { :automatic_request }
  let(:work) { create(:oral_history_work, :available_by_request, published: true, availability_mode: availability_mode) }
  let(:published_members) { work.members.select(&:published?) }
  let(:patron) { create(:patron) }

  describe "#members_viewable_by" do
    it "is all members for staff" do
      expect(work.members_viewable_by(user: create(:staff_viewer_user), patron: nil)).to match_array(work.members)
    end

    it "is published members for anonymous" do
      expect(work.members_viewable_by(user: nil, patron: nil)).to match_array(published_members)
    end

    it "includes by-request members for patron with access" do
      expect(work.members_viewable_by(user: nil, patron: patron)).to match_array(work.members)
    end

    it "is published members for patron without access" do
      expect(work.members_viewable_by(user: nil, patron: create(:patron, :unconfirmed))).to match_array(published_members)
    end

    describe "direct work" do
      let(:availability_mode) { :direct }

      it "excludes by-request flagged members for patron" do
        expect(work.members_viewable_by(user: nil, patron: patron)).to match_array(published_members)
      end
    end
  end
end
