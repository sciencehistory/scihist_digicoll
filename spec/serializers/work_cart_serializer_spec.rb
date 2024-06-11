require 'rails_helper'

describe WorkCartSerializer do
  let(:scope) { Work.all.includes(:leaf_representative, :contained_by) }
  let(:report) { WorkCartSerializer.new(scope).to_a }

  context "smoke test with two works" do
    let!(:work_1) { create(:public_work, title: "Title of work 1") }
    let!(:work_2) { create(:public_work, title: "Title of work 2") }
    it "returns a report with correct titles and one row per work" do
      expect(report[0]).to eq [
        "Title", "Additional title",
        "URL", "External ID", "Department", "Creator",
        "Date", "Medium", "Extent", "Place", "Genre",
        "Description", "Subject/s", "Series Arrangement",
        "Physical Container", "Collection", "Rights",
        "Rights Holder", "Additional Credit",
        "Digitization Funder", "Admin Note",
        "Created", "Last Modified"
      ]
      expect(report.length).to eq 3
    end
  end

  context "work with all metadata in it" do
    let!(:work_1) { create(:public_work, :with_complete_metadata, :with_collection,
        place_attributes: {"0"=>{"category"=> "place_of_creation", "value"=>"Illinois--Peoria"}},
        subject: ['s1', 's2', 's3'],
    ) }
    it "values are correct; all columns present" do
      expect(report.length).to eq 2
      expect(report[1][0]).to  eq 'Test title'
      expect(report[1][1]).to  eq 'Additional Title 1|Additional Title 2'
      expect(report[1][2]).to  match /http.*works/
      expect(report[1][3]).to  eq 'Past Perfect ID 1|Sierra Bib Number 1|Sierra Bib Number 2|Accession Number 1'
      expect(report[1][4]).to  eq 'Center for Oral History'
      expect(report[1][5]).to  eq 'After 1|Author 1|Contributor 1'
      expect(report[1][6]).to  eq 'Before 2014-Jan-01 – circa 2014-Jan-02 (Note 1)|Before 2014-Feb-03 – circa 2014-Feb-04 (Note 2)|Before 2014-Mar-05 – circa 2014-Mar-06 (Note 3)'
      expect(report[1][7]).to  eq 'Audiocassettes|Celluloid|Dye'
      expect(report[1][8]).to  eq '0.75 in. H x 2.5 in. W|80 cm L x 22 cm Diam.'
      expect(report[1][9]).to  eq 'Illinois--Peoria'    # place
      expect(report[1][10]).to eq 'Lithographs'         # genre
      expect(report[1][11]).to eq 'Description 1'       # description
      expect(report[1][12]).to eq 's1|s2|s3'            # subject
      expect(report[1][13]).to eq 'Series arrangement 1|Series arrangement 2'
      expect(report[1][14]).to eq 'Box: Box|Page: Page|Part: Part|Reel: Reel|Folder: Folder|Volume: Volume|Shelfmark: Shelfmark'
      expect(report[1][15]).to eq 'Test title' # collection
      expect(report[1][16]).to eq "http://rightsstatements.org/vocab/NoC-US/1.0/"
      expect(report[1][17]).to eq "Rights Holder"
      expect(report[1][18]).to eq "photographed_by:Douglas Lockard|photographed_by:Mark Backrath"
      expect(report[1][19]).to eq "Daniel Sanford"
      expect(report[1][20]).to eq "Admin Note"
      expect(Date.parse(report[1][21])).to be_a Date
      expect(Date.parse(report[1][22])).to be_a Date
    end
  end

  context "do not include child works; respect order of columns" do
    let!(:parent) { create(:public_work,
        title: "The parent",
        members: [child],
        creator_attributes: {
          "0"=>{"category"=> "author",    "value"=>"creator1"},
          "1"=>{"category"=> "publisher", "value" => "publisher1 " }
          },
        )
    }
    let(:child) { create(:public_work, title: "child title") }
    let(:scope) { Work.where(title: 'The parent') }
    let(:report) { WorkCartSerializer.new(scope, columns: [:creator, :title]).to_a }
    it "returns a report" do
      expect(report).to match_array([["Creator", "Title"], ["creator1|publisher1 ", "The parent"]])
    end
  end

end
