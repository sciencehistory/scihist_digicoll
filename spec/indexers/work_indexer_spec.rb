require 'rails_helper'

describe WorkIndexer do
  let(:work) { create(:work, :with_complete_metadata) }

  it "indexes" do
    output_hash = WorkIndexer.new.map_record(work)
    expect(output_hash).to be_present
  end
end
