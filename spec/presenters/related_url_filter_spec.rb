require 'rails_helper'

describe RelatedUrlFilter do
  let(:opac_urls) {[
    "http://othmerlib.sciencehistory.org/record=b1",
    "https://othmerlib.sciencehistory.org/record=b2",
    "http://othmerlib.chemheritage.org/record=b3"
  ]}
  let(:related_work_urls) {[
    "http://digital.sciencehistory.org/works/work1",
    "https://digital.sciencehistory.org/works/work2"
  ]}
  let(:generic_urls) {[
    "http://example.org/foo",
    "https://example.org/bar"
  ]}

  let(:all_urls) { opac_urls + related_work_urls + generic_urls }

  let(:filter) { RelatedUrlFilter.new(all_urls) }

  it "filters" do
    expect(filter.filtered_related_urls).to eq(generic_urls)
    expect(filter.opac_urls).to eq(opac_urls)
    expect(filter.related_work_urls).to eq(related_work_urls)
  end

  it "extracts related_work_friendlier_ids" do
    expect(filter.related_work_friendlier_ids).to eq(["work1", "work2"])
  end

  it "extracts opac_ids" do
    expect(filter.opac_ids).to eq(["b1", "b2", "b3"])
  end

  describe "weird sierra extra url" do
    let(:opac_urls) {["http://othmerlib.sciencehistory.org/record=b1069527~S5"]}

    it "ignores weird suffix" do
      expect(filter.opac_ids).to eq(["b1069527"])
    end
  end

  describe "nil input" do
    let(:filter) { RelatedUrlFilter.new(nil) }
    it "has empty output" do
      expect(filter.filtered_related_urls).to eq []
      expect(filter.opac_urls).to eq []
      expect(filter.related_work_urls).to eq []

      expect(filter.related_work_friendlier_ids).to eq []
      expect(filter.opac_ids).to eq []
    end
  end

end
