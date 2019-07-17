require 'rails_helper'

describe OnDemandDerivativeCreator, queue_adapter: :test do
  let(:deriv_type) { "zip_file" }
  let(:work) { create(:work, members: [create(:asset_with_faked_file), create(:asset_with_faked_file)]) }
  let(:creator) { OnDemandDerivativeCreator.new(work, derivative_type: deriv_type) }
  let(:checksum) { creator.calculated_checksum }


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

    describe "stale record" do
      let!(:existing) { OnDemandDerivative.create!(work: work, deriv_type: deriv_type, status: "success", inputs_checksum: "bad_checksum") }

      it "re-creates" do
        record = creator.find_or_create_record

        expect { existing.reload }.to raise_error(ActiveRecord::RecordNotFound)

        expect(record.work_id).to eq work.id
        expect(record.deriv_type).to eq deriv_type
        expect(record.status).to eq "in_progress"
        expect(record.inputs_checksum).to eq checksum

        expect(OnDemandDerivativeCreatorJob).to have_been_enqueued
      end
    end
  end

  describe "attach_derivative!" do
    let!(:on_demand_derivative) { OnDemandDerivative.create!(work: work, deriv_type: deriv_type, status: "in_progress", inputs_checksum: checksum) }

    it "attaches derivative" do
      # just make it faster
      allow_any_instance_of(WorkZipCreator).to receive(:create).and_return(Tempfile.new)

      creator.attach_derivative!

      on_demand_derivative.reload
      expect(on_demand_derivative.status).to eq "success"
      expect(on_demand_derivative.file_exists?).to be(true)
    end

    it "records error and re-raises" do
      allow_any_instance_of(WorkZipCreator).to receive(:create).and_raise(ArgumentError.new("made this error"))

      expect {
        creator.attach_derivative!
      }.to raise_error("made this error")

      on_demand_derivative.reload
      expect(on_demand_derivative.status).to eq "error"
    end
  end

  describe "calculated_checksum" do
    it "changes with member change" do
      original_checksum = checksum

      work.members.first.destroy

      new_creator = OnDemandDerivativeCreator.new(work, derivative_type: deriv_type)

      expect(new_creator.calculated_checksum).not_to eq original_checksum
    end
  end

end
