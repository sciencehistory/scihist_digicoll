require 'rails_helper'

describe WorkShowInfo do
  let(:work) {  build(:work, external_id: {category: "bib", value: "b1075359"}, related_url: "https://othmerlib.sciencehistory.org/record=b1075359")}
  context "with duplicate bibnum and related url" do
    it "has only one links_to_opac" do
      links = WorkShowInfo.new(work).links_to_opac
      expect(links).to eq(["https://othmerlib.sciencehistory.org/record=b1075359"])
    end
  end

  context "with weird almost-matching dups" do
    let(:work) {  build(:work, external_id: {category: "bib", value: "B10722609"}, related_url: "https://othmerlib.sciencehistory.org/record=b1072260")}
    it "still only has one link to opac" do
      links = WorkShowInfo.new(work).links_to_opac
      expect(links).to eq(["https://othmerlib.sciencehistory.org/record=b1072260"])
    end
  end

end
