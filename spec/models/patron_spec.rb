require 'rails_helper'

describe Patron, type: :model do
  describe ".find_or_create_from_form" do
    it "creates a new patron with attributes" do
      patron = Patron.find_or_create_from_form(email: " New@Example.com ", name: "New", institution: "U")
      expect(patron).to be_persisted
      expect(patron.email).to eq "new@example.com"
      expect(patron.name).to eq "New"
      expect(patron.institution).to eq "U"
    end

    it "returns unsaved patron with errors when name missing" do
      patron = Patron.find_or_create_from_form(email: "new@example.com", name: "")
      expect(patron).not_to be_persisted
      expect(patron.errors[:name]).to be_present
    end

    it "returns existing patron unchanged" do
      existing = create(:patron, email: "old@example.com", name: "Old")
      patron = Patron.find_or_create_from_form(email: "OLD@example.com", name: "Attacker", institution: "Evil")
      expect(patron).to eq existing
      expect(patron.reload.name).to eq "Old"
      expect(patron.institution).to be_nil
    end
  end

  describe "#confirm!" do
    it "confirms" do
      patron = create(:patron, :unconfirmed)
      expect(patron).not_to be_confirmed
      patron.confirm!
      expect(patron.reload).to be_confirmed
    end
  end

  describe "#can_access_oral_history?" do
    let(:patron) { create(:patron) }
    let(:work) { create(:oral_history_work, :available_by_request, published: true, availability_mode: availability_mode) }

    describe("automatic_request") do
      let(:availability_mode) { :automatic_request }

      it "is true for automatic_request" do
        expect(patron.can_access_oral_history?(work)).to be true
      end

      it "is false when not confirmed" do
        patron.update!(confirmed_at: nil)
        expect(patron.can_access_oral_history?(work)).to be false
      end

      it "is false when work unpublished" do
        work.update!(published: false)
        expect(patron.can_access_oral_history?(work)).to be false
      end

      it "is true without oral_history_content, even unconfirmed" do
        patron.update!(confirmed_at: nil)
        expect(patron.can_access_oral_history?(create(:public_work))).to be true
      end
    end

    describe "direct" do
      let(:availability_mode) { :direct }

      it "is true even when not confirmed" do
        patron.update!(confirmed_at: nil)
        expect(patron.can_access_oral_history?(work)).to be true
      end

      it "is false when work unpublished" do
        work.update!(published: false)
        expect(patron.can_access_oral_history?(work)).to be false
      end
    end

    describe "embargoed" do
      let(:availability_mode) { :embargoed }

      it "is false always, even with approved request" do
        create(:oral_history_request, patron: patron, work: work, delivery_status: "approved")
        expect(patron.can_access_oral_history?(work)).to be false
      end
    end

    describe "reviewed_request" do
      let(:availability_mode) { :reviewed_request }

      it "is false with no request" do
        expect(patron.can_access_oral_history?(work)).to be false
      end

      it "is false with pending request" do
        create(:oral_history_request, patron: patron, work: work, delivery_status: "pending")
        expect(patron.can_access_oral_history?(work)).to be false
      end

      it "is false with someone else's approved request" do
        create(:oral_history_request, work: work, delivery_status: "approved")
        expect(patron.can_access_oral_history?(work)).to be false
      end

      it "is true with approved request" do
        create(:oral_history_request, patron: patron, work: work, delivery_status: "approved")
        expect(patron.can_access_oral_history?(work)).to be true
      end
    end
  end
end
