require "rails_helper"

describe HocrSearcher do
  # set height and width to match the faked HOCR
  let(:asset) { create(:asset_with_faked_file, :with_ocr, faked_width: 2767, faked_height: 3558)}
  let(:work) { create(:public_work, members: [ asset ])}

  it "produces matches" do
    searcher = HocrSearcher.new(work, query: "units")

    results = searcher.results_for_osd_viewer
    expect(results).to be_kind_of(Array)
    expect(results.length).to be 1

    result = results.first
    expect(result).to be_kind_of(Hash)
    expect(result['text']).to be_kind_of(String)
    expect(result['osd_rect']).to be_kind_of(Hash)

    # sanity check
    %w{left top height width}.each do |key|
      expect(result['osd_rect'][key]).to be_kind_of(Float)
      expect(result['osd_rect'][key]).not_to eq(Float::INFINITY)
      expect(result['osd_rect'][key]).to be < (asset.width * 4)
    end
  end
end
