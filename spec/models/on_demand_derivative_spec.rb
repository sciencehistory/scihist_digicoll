require 'rails_helper'

describe OnDemandDerivative do
  let(:work) { create(:work) }
  let(:deriv_type) { "pdf_file" }
  let(:checksum) { "fake_checksum" }

  let(:on_demand_derivative) { OnDemandDerivative.create!(
    work: work,
    deriv_type: deriv_type,
    inputs_checksum: checksum
  )}

  let(:file) { File.open((Rails.root + "spec/test_support/images/30x30.png")) }


  it "can put and access file" do
    expect(on_demand_derivative.file_exists?).to be false

    on_demand_derivative.put_file(file)

    expect(on_demand_derivative.file_exists?).to be true

    expect(on_demand_derivative.file_url).to be_present
    expect(on_demand_derivative.file_url).to end_with(".pdf")
  end
end
