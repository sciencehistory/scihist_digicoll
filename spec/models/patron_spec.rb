require 'rails_helper'

describe Patron, type: :model do
  let(:patron) { Patron.new(email: "example#{rand(999999)}@example.com") }
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
