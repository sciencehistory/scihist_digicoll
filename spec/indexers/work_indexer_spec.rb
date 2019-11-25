require 'rails_helper'

describe WorkIndexer do
  let(:work) { create(:work, :with_complete_metadata) }

  it "indexes" do
    output_hash = WorkIndexer.new.map_record(work)
    expect(output_hash).to be_present

    expect(output_hash["model_pk_ssi"]).to eq([work.id])
  end

  describe "with containers" do
    let(:collection1) {  create(:collection) }
    let(:collection2) {  create(:collection) }
    let(:work) {  create(:work, contained_by: [collection1, collection2] ) }

    it "indexes collection ids" do
      work.contains_contained_by.reload # not sure what we're working around, but okay
      output_hash = WorkIndexer.new.map_record(work)

      expect(output_hash["collection_id_ssim"]).to match [collection1.id, collection2.id]
    end
  end

  describe "empty string department" do
    let(:work) { create(:work, department: "") }
    it "indexes as nil" do
      output_hash = WorkIndexer.new.map_record(work)
      expect(output_hash).not_to include("department_facet")
    end
  end

end
