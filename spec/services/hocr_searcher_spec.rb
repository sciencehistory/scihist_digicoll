require "rails_helper"

describe HocrSearcher do
  let(:work) { create(:public_work, members: [ create(:asset, :with_ocr)])}

  it "produces matches" do
    searcher = HocrSearcher.new(work, query: "units")

    results = searcher.matches
    expect(results).to be_kind_of(Array)
    expect(results.length).to be 1
  end
end
