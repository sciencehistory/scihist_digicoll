require 'rails_helper'

describe WorkShowInfoComponent, type: :component do
  let(:work) {  build(:work, external_id: {category: "bib", value: "b1075359"}, related_url: "https://othmerlib.sciencehistory.org/record=b1075359")}

  context "#links_to_opac" do
    context "with duplicate bibnum and related url" do
      it "has only one links_to_opac" do
        links = WorkShowInfoComponent.new(work: work).links_to_opac
        expect(links).to eq(["https://othmerlib.sciencehistory.org/record=b1075359"])
      end
    end

    context "with weird almost-matching dups" do
      let(:work) {  build(:work, external_id: {category: "bib", value: "B10722609"}, related_url: "https://othmerlib.sciencehistory.org/record=b1072260")}
      it "still only has one link to opac" do
        links = WorkShowInfoComponent.new(work: work).links_to_opac
        expect(links).to eq(["https://othmerlib.sciencehistory.org/record=b1072260"])
      end
    end
  end

  context "Oral History Number" do
    let(:work) {
      build(:oral_history_work, external_id: [
          {'category' => 'bib', 'value' => 'b1043559'},
          {'category' => 'interview', 'value' => '0012'}
      ])
    }

    it "displays oral history number" do
      render_inline WorkShowInfoComponent.new(work: work)
      expect(page).to have_text(/Oral history number\s+0012/)
    end
  end
end
