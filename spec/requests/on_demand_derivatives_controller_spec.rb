require 'rails_helper'

RSpec.describe OnDemandDerivativesController, type: :request, queue_adapter: :test do
  let(:derivative_type) { "zip_file" }
  let(:work) { create(:work) }

  describe "initial request" do
    it "creates record and returns json" do
      expect(OnDemandDerivativeCreatorJob).to receive(:perform_later).once

      get on_demand_derivative_status_path(work.friendlier_id, derivative_type)

      expect(response.content_type).to eq("application/json")
      expect(response).to have_http_status(200)

      json = JSON.parse(response.body)

      expect(json["work_id"]).to eq work.id
      expect(json["status"]).to eq "in_progress"

      last = OnDemandDerivative.last
      expect(last).to be_present
      expect(last.work_id).to eq work.id
    end
  end

  describe "finished processing" do
    let(:creator) { OnDemandDerivativeCreator.new(work, derivative_type: derivative_type) }

    before do
      # Try to keep it faster by not making a real zip
      allow_any_instance_of(WorkZipCreator).to receive(:create).and_return(Tempfile.new)
    end

    let!(:record) do
      OnDemandDerivative.create!(work: work, deriv_type: derivative_type, inputs_checksum: creator.calculated_checksum).tap do |record|
        creator.attach_derivative!
      end
    end

    it "returns json" do
      expect(OnDemandDerivativeCreatorJob).not_to receive(:perform_later)

      get on_demand_derivative_status_path(work.friendlier_id, derivative_type)

      expect(response.content_type).to eq("application/json")
      expect(response).to have_http_status(200)

      json = JSON.parse(response.body)

      expect(json["id"]).to eq record.id
      expect(json["status"]).to eq "success"
      expect(json["file_url"]).to be_kind_of String
    end
  end

end
