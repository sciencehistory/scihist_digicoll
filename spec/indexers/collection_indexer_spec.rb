require 'rails_helper'

describe CollectionIndexer do
  let(:collection) { create(:collection) }

  it "indexes" do
    output_hash = CollectionIndexer.new.map_record(collection)
    expect(output_hash).to be_present

    expect(output_hash["model_pk_ssi"]).to eq([collection.id])
  end
end
