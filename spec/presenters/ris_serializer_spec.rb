require 'rails_helper'

describe RisSerializer do
  let(:work) do
    FactoryBot.build(:work,
      friendlier_id:  "TEST_FRIENDLIER_ID",
      title: "Test title",
      date_of_work:  [],
      creator: [
        {category: "creator_of_work",  value: "Hawes, R. C."},
        {category: "publisher", value: "Sackett, Israel, 1809-1880"}
      ],
      place: [
        {category: "place_of_publication",  value: "New York (State)--New York"}
      ],
      description: 'This is an abstract',
      subject: ['subject2'],
      language: ['English', 'German']
    )
  end
  let(:serializer) { RisSerializer.new(work) }
  let(:serialized) { serializer.to_ris }
  let(:serialized_fields) do
    serialized.split(RisSerializer::RIS_LINE_END).collect do |line|
      (tag, value) = line.split("  - ")
      [tag, value || nil]
    end.to_h
  end

  it "serializes" do
    expect(serialized).to be_present
  end

  it "serializes as expected" do
    expect(serialized_fields["TY"]).to be_present

    expect(serialized_fields["DB"]).to eq "Science History Institute"
    expect(serialized_fields["DP"]).to eq "Science History Institute"
    expect(serialized_fields["M2"]).to eq "Courtesy of Science History Institute."
    expect(serialized_fields["TI"]).to eq "Test title"
    expect(serialized_fields["AU"]).to eq "Hawes, R. C."
    expect(serialized_fields["PB"]).to eq "Israel Sackett"
    expect(serialized_fields["CY"]).to eq "New York, New York"
    expect(serialized_fields["UR"]).to eq "https://localhost/works/TEST_FRIENDLIER_ID"
    expect(serialized_fields["AB"]).to eq "This is an abstract"
    expect(serialized_fields["KW"]).to eq "subject2"
    expect(serialized_fields["LA"].split(", ")).to match_array(["English", "German"])
  end

  describe "dates" do
    before do
      work.date_of_work =  [ Work::DateOfWork.new(start: "1920", finish: "", start_qualifier: "decade", finish_qualifier: "", note: "") ]
    end

    describe "decade" do
      it "chooses start as RIS date" do
        expect(serialized_fields["DA"]).to eq("1920///")
        expect(serialized_fields["YR"]).to eq("1920")
      end
    end
  end

  describe "complex archival work" do
    let(:collection) { FactoryBot.build(:collection, title: "Collection Title") }
    let(:parent_work) { FactoryBot.build(:work, title: "parent_work") }
    let(:work) do
      FactoryBot.build(:work,
        title: "Work title",
        creator: [
          {category: "creator_of_work",  value: "Hawes, R. C."},
          {category: "publisher", value: "Sackett, Israel, 1809-1880"}
        ],
        place: [
          {category: "place_of_publication",  value: "New York (State)--New York"}
        ],
        description: 'This is an abstract',
        subject: ['subject1', 'subject2'],
        language: ['English', 'German'],
        department: "Archives",
        series_arrangement: ["Sub-series 2. Advertisements", "Series VIII. Clippings and Advertisements"],
        physical_container:  {box:'49', folder: '14' },
        date_of_work: [Work::DateOfWork.new(start: "1916-05-04")],
        rights: "http://rightsstatements.org/vocab/InC-RUU/1.0/"
      )
    end
    let(:serializer) { RisSerializer.new(work) }
    before do
      collection.contains << work
      work.parent_id = parent_work.id
      work.position = 0
      work.save!
    end

    it "serializes as expected" do
      expect(serialized_fields["DB"]).to eq "Science History Institute"
      expect(serialized_fields["DP"]).to eq "Science History Institute"
      expect(serialized_fields["AV"]).to eq "Collection Title, Box 49, Folder 14"
      expect(serialized_fields["TI"]).to eq "Work title"
      expect(serialized_fields["T2"]).to eq "parent_work"
      expect(serialized_fields["YR"]).to eq "1916"
      expect(serialized_fields["DA"]).to eq "1916/05/04/"
      expect(serialized_fields["M2"]).to eq "Courtesy of Science History Institute.  Rights: In Copyright - Rights-holder(s) Unlocatable or Unidentifiable"
    end
  end

end
