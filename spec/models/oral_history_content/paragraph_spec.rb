require 'rails_helper'

describe OralHistoryContent::Paragraph do
  describe "JSON serialization" do
    let(:paragraph) do
      described_class.new(
        text: "foo",
        paragraph_index:12,
        included_timestamps:[1020],
        pdf_logical_page_number: 2
      ).tap do |p|
        p.assumed_speaker_name = "ROCHKIND"
        p.previous_timestamp = 900
      end
    end

    it "round trips to json" do
      json = paragraph.as_json
      expect(json).to be_kind_of(Hash)
      expect(json).to be_present

      newp = described_class.from_json(json)

      expect(newp.as_json).to eq json
    end

    it "to_json is string" do
      expect(paragraph.as_json.to_json).to eq paragraph.to_json
    end

    it "has instance vars equiv after round-tripping" do
      newp = described_class.from_json(paragraph.as_json)

      paragraph.instance_variables.each do |ivar_name|
        expect(paragraph.instance_variable_get(ivar_name)).to eq (
          newp.instance_variable_get(ivar_name)
        )
      end
    end
  end
end
