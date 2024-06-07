require 'rails_helper'

describe CartExporter do
  let!(:work_1) { create(:public_work, title: "Title of work 1") }
  let!(:work_2) { create(:public_work, title: "Title of work 2") }
  let(:scope) { Work.all.includes(:leaf_representative, :contained_by) }
  let(:report) { CartExporter.new(scope).to_a }

  context "smoke test" do
    it "returns a report" do
      expect(report.length).to eq 3
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
      expect(report[1][0]).to  match /Title of work/
      expect(report[1][3]).to  match /Past Perfect ID 1|Sierra Bib Number 1|Sierra Bib Number 2|Accession Number 1/
      expect(report[1][4]).to  match /Library/
      expect(report[1][6]).to  match /2019/
      expect(report[1][10]).to match /Rare books/
      expect(report[1][16]).to eq "http://creativecommons.org/publicdomain/mark/1.0/"
      expect(Date.parse(report[1][21])).to be_a Date
      expect(Date.parse(report[1][22])).to be_a Date
    end
  end

  context "include child works; respect order of columns" do
    let!(:work_2) { create(:public_work,
        title: "Title of work 2",
        members: [work_1],
        creator_attributes: {
          "0"=>{"category"=> "author",    "value"=>"creator1"},
          "1"=>{"category"=> "publisher", "value" => "publisher1 " }
          },
        )
    }
    let(:report) { CartExporter.new(scope, columns: [:creator, :title]).to_a }
    it "returns a report" do
      expect(report).to match_array([["Creator", "Title"], ["creator1|publisher1 ", "Title of work 2"], ["", "Title of work 1"]])
    end
  end

end
