require 'rails_helper'

describe WorkProvenanceDisplay do

  let(:work_0) { FactoryBot.create(:work, provenance:  nil )}
  let(:work) { FactoryBot.create(:work, provenance:  "provenance metadata" )}

  it "returns an empty string if provenance is blank" do
    expect(WorkProvenanceDisplay.new(work_0).display). to eq ""
  end

  it "correctly splits the provenance" do
    expect {
        WorkProvenanceDisplay.new(work_0).split_provenance
    }.to raise_error(ArgumentError)

    #no notes
    expect(WorkProvenanceDisplay.new(work).split_provenance).
      to contain_exactly("provenance metadata")

    work.provenance = "provenance metadata \n\n NOTES: \n\n notes"
    expect(WorkProvenanceDisplay.new(work).split_provenance).
      to contain_exactly("provenance metadata", "notes")

    work.provenance = "provenance metadata \n\n NOTES: \n\n notes"
    expect(WorkProvenanceDisplay.new(work).split_provenance).
      to contain_exactly("provenance metadata", "notes")

    work.provenance = "provenance metadata \n\n Notes: \n\n notes"
    expect(WorkProvenanceDisplay.new(work).split_provenance).
      to contain_exactly("provenance metadata", "notes")

    work.provenance = "provenance metadata \r\n NOTES: \r\n notes"
    expect(WorkProvenanceDisplay.new(work).split_provenance).
      to contain_exactly("provenance metadata", "notes")

    work.provenance = "provenance metadata \r\n NOTES: \r\n notes \r\n NOTES: \r\n notes \r\n NOTES: \r\n notes"
    expect(WorkProvenanceDisplay.new(work).split_provenance).
      to contain_exactly("provenance metadata", "notes \r\n NOTES: \r\n notes \r\n NOTES: \r\n notes")

  end
end
