require "rails_helper"

describe HocrSearcher do
  # set height and width to match the faked HOCR
  let(:asset) { create(:asset_with_faked_file, :with_ocr, published: true, faked_width: 2767, faked_height: 3558) }
  let(:work) { create(:public_work, members: [ asset, create(:asset_with_faked_file) ])}

  it "produces matches" do
    searcher = HocrSearcher.new(work, query: "units")

    results = searcher.results_for_osd_viewer
    expect(results).to be_kind_of(Array)
    expect(results.length).to be 1

    result = results.first
    expect(result).to be_kind_of(Hash)
    expect(result["id"]).to eq asset.friendlier_id
    expect(result['text']).to be_kind_of(String)
    expect(result['text']).to match "<mark>units</mark>"
    expect(result['osd_rect']).to be_kind_of(Hash)

    # sanity check
    %w{left top height width}.each do |key|
      expect(result['osd_rect'][key]).to be_kind_of(Float)
      expect(result['osd_rect'][key]).not_to eq(Float::INFINITY)
      expect(result['osd_rect'][key]).to be < (asset.width * 4)
    end
  end

  # This needs to match what the viewer itself does, when we wrote this it does
  describe "with child work" do
    let(:parent_work) { create(:public_work, members: [work]) }

    it "includes single representative, with direct member id" do
      searcher = HocrSearcher.new(parent_work, query: "units")

      results = searcher.results_for_osd_viewer
      expect(results).to be_kind_of(Array)
      expect(results.length).to be 1

      expect(results.first["id"]).to eq work.friendlier_id
    end
  end

  describe "with unpublished member" do
    let(:asset) { create(:asset_with_faked_file, :with_ocr, published: false, faked_width: 2767, faked_height: 3558) }

    it "does not include unpublished asset" do
      searcher = HocrSearcher.new(work, query: "units")
      expect(searcher.results_for_osd_viewer).not_to include(an_object_satisfying { |h| h["id"] == asset.friendlier_id })
    end

    context "when including unpublished" do
      it "includes unpublished asset" do
        searcher = HocrSearcher.new(work, show_unpublished: true, query: "units")

        expect(searcher.results_for_osd_viewer).to include(an_object_satisfying { |h| h["id"] == asset.friendlier_id })
      end
    end
  end
end
