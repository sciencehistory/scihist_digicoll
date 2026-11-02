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

    it "returns existing patron unchanged" do
      existing = Patron.create!(email: "old@example.com", name: "Old")
      patron = Patron.find_or_create_from_form(email: "OLD@example.com", name: "Attacker", institution: "Evil")
      expect(patron).to eq existing
      expect(patron.reload.name).to eq "Old"
      expect(patron.institution).to be_nil
    end
  end

  describe "#confirm!" do
    it "confirms" do
      patron = Patron.create!(email: "x@example.com", name: "Test Patron")
      expect(patron).not_to be_confirmed
      patron.confirm!
      expect(patron.reload).to be_confirmed
    end
  end

  let(:patron) { Patron.new(email: "example#{rand(999999)}@example.com", name: "Test Patron") }
  describe "#has_approved_request?" do
    describe "with no request" do
      let(:asset) { create(:asset) }

      it "is false" do
        expect(patron.has_approved_request_for_asset?(asset)).to be false
      end
    end

    describe "with pending request" do
      let!(:oral_history_request) { create(:oral_history_request, patron: patron, delivery_status: "pending") }
      let(:asset) { oral_history_request.work.members.find { |m| m.oh_available_by_request? } }

      it "is false" do
        expect(patron.has_approved_request_for_asset?(asset)).to be false
      end
    end

    describe "with approved request" do
      let!(:oral_history_request) { create(:oral_history_request, patron: patron, delivery_status: "approved") }
      let(:asset) { oral_history_request.work.members.find { |m| m.oh_available_by_request? } }

      it "is true" do
        expect(patron.has_approved_request_for_asset?(asset)).to be true
      end
    end

    describe "with automatic request" do
      let!(:oral_history_request) { create(:oral_history_request, patron: patron, delivery_status: "automatic") }
      let(:asset) { oral_history_request.work.members.find { |m| m.oh_available_by_request? } }

      it "is true" do
        expect(patron.has_approved_request_for_asset?(asset)).to be true
      end
    end
  end
end
