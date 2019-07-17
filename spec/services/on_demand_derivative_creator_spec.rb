require 'rails_helper'

describe OnDemandDerivativeCreator, queue_adapter: :test do
  let(:deriv_type) { "zip_file" }
  let(:work) { create(:work, members: [create(:asset, :inline_promoted_file), create(:asset, :inline_promoted_file)]) }
  let(:creator) { OnDemandDerivativeCreator.new(work, derivative_type: deriv_type) }

  describe "find_or_create_record" do
    describe "initial" do
      it "creates in_progress_record" do
        record = nil
        expect {
          record = creator.find_or_create_record
        }.to change { OnDemandDerivative.count }.by(1)

        expect(record).to be_present
        expect(record.work_id).to eq work.id
        expect(record.status).to eq "in_progress"
        expect(record.deriv_type).to eq deriv_type

        expect(OnDemandDerivativeCreatorJob).to have_been_enqueued
      end
    end

    describe "already in_progress" do
      let(:checksum) { creator.calculated_checksum }
      let!(:existing) { OnDemandDerivative.create!(work: work, deriv_type: deriv_type, status: "in_progress", inputs_checksum: checksum) }

      it "re-uses existing record" do
        record = nil
        expect {
          record = creator.find_or_create_record
        }.not_to change { User.count }

        expect(OnDemandDerivativeCreatorJob).not_to have_been_enqueued

        expect(record.id).to eq(existing.id)
        expect(record.status).to eq("in_progress")
      end
    end
  end
end
