require 'rails_helper'

describe OralHistoryContent::OhmsXml::LegacyTranscript do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/legacy/duarte_OH0344.xml"}
  let(:legacy_transcript) { described_class.new(Nokogiri::XML(File.read(ohms_xml_path)))}
  let(:ohms_xml_path_with_footnotes) { Rails.root + "spec/test_support/ohms_xml/legacy/hanford_OH0139.xml"}
  let(:legacy_transcript_with_footnotes) { described_class.new(Nokogiri::XML(File.read(ohms_xml_path_with_footnotes)))}

  describe "#sync_timecodes" do
    it "are as expected" do
      # we'll just check a sampling, we have one-second interval granularity in XML
      expect(legacy_transcript.sync_timecodes.count).to eq(28)
      expect(legacy_transcript.sync_timecodes[13]).to  eq([{:line_number=>"13", :seconds=>60,  :word_number=>3}])
      expect(legacy_transcript.sync_timecodes[19]).to  eq([{:line_number=>"19", :seconds=>120, :word_number=>14}])
      expect(legacy_transcript.sync_timecodes[308]).to eq([{:line_number=>"308", :seconds=>1680, :word_number=>2}])
    end
  end

  describe "#accession_id" do
    it "comes from XML" do
      expect(legacy_transcript.accession_id).to eq "OH0344"
    end
  end

  describe "#paragraphs" do
    it "returns good paragraphs" do
      expect(legacy_transcript.paragraphs).to be_present
      expect(legacy_transcript.paragraphs).to all(be_kind_of(OralHistoryContent::OhmsXml::LegacyTranscript::Paragraph))

      legacy_transcript.paragraphs.each do |paragraph|
        expect(paragraph.lines).to all(be_kind_of(OralHistoryContent::OhmsXml::LegacyTranscript::Line))

        expect(paragraph.paragraph_index).to be_kind_of(Integer)
      end

      legacy_transcript.paragraphs.each do |paragraph|
        expect(paragraph.line_number_range).to be_kind_of(Range)
        expect(paragraph.line_number_range.first).to be_present
        expect(paragraph.line_number_range.last).to be_present
        expect(paragraph.line_number_range).not_to be_exclude_end
      end

      expect(legacy_transcript.paragraphs.first.text).to eq "BROCK: This is an oral history interview with Ron Duarte taking place on 13 June 2006. The interviewer is David Brock. Ron, I believe that you were born in Pescadero [Pescadero, California] but I'm not sure exactly when."
      expect(legacy_transcript.paragraphs.second.text).to eq "DUARTE: On 7 May 1930."
      expect(legacy_transcript.paragraphs.last.text).to eq "[END OF INTERVIEW]"
    end

    it "include lines with numbers" do
      # Exact line numbers as in original text file transcript are important for timecode sync in
      # legacy ohms format.
      paragraph = legacy_transcript.paragraphs.third
      expect(paragraph.paragraph_index).to eq 3
      expect(paragraph.lines.count).to eq 3
      expect(paragraph.line_number_range).to eq (7..9)

      expect(paragraph.lines.first.line_num).to eq 7
      expect(paragraph.lines.first.text).to eq "BROCK: Tell us a little bit about your family background and your family's"

      expect(paragraph.lines.second.line_num).to eq 8
      expect(paragraph.lines.second.text).to eq "history in Pescadero."

      expect(paragraph.lines.third.line_num).to eq 9
      expect(paragraph.lines.third.text).to eq ""
    end

    it "include timestamps" do
      expect(legacy_transcript.paragraphs.first.included_timestamps).to eq []
      expect(legacy_transcript.paragraphs.first.previous_timestamp).to eq 0

      expect(legacy_transcript.paragraphs.second.included_timestamps).to eq []
      expect(legacy_transcript.paragraphs.third.previous_timestamp).to eq 0

      expect(legacy_transcript.paragraphs.fourth.included_timestamps).to eq [60, 120, 180]
      expect(legacy_transcript.paragraphs.fourth.previous_timestamp).to eq 0

      expect(legacy_transcript.paragraphs.fifth.included_timestamps).to eq []
      expect(legacy_transcript.paragraphs.fifth.previous_timestamp).to eq 180
    end
  end

  describe "#transcript_lines_text" do
    it "strips footnote section from the text" do
      expect(legacy_transcript_with_footnotes.transcript_lines_text).to be_present
      all_text = legacy_transcript_with_footnotes.transcript_lines_text.join("\n")
      expect(all_text).not_to match(%r{\[\[/?footnotes\]\]})
    end
    it "correctly outputs an empty array of footnotes when none are present" do
      expect(legacy_transcript.transcript_lines_text).to be_present
      expect(legacy_transcript.footnote_array).to eq []
    end
    it "keeps references to the footnotes in the text, if they are present" do
      all_text = legacy_transcript_with_footnotes.transcript_lines_text.join("\n")
      expect(all_text).to match(/\[\[footnote\]\]1\[\[\/footnote\]\]/)
      expect(all_text).to match(/\[\[footnote\]\]2\[\[\/footnote\]\]/)
    end
    it "makes footnotes available via the footnote array" do
      expect(legacy_transcript_with_footnotes.footnote_array.length).to eq 2
      expect(legacy_transcript_with_footnotes.footnote_array[0]).to match(/Polyamides/)
      expect(legacy_transcript_with_footnotes.footnote_array[1]).to match(/Lucille/)
    end

    it "makes footnotes available via the footnote array" do
      expect(legacy_transcript_with_footnotes.footnote_array.length).to eq 2
      expect(legacy_transcript_with_footnotes.footnote_array[0]).to match(/Polyamides/)
      expect(legacy_transcript_with_footnotes.footnote_array[1]).to match(/Lucille/)
    end
  end

  describe "#footnote_array" do
    let(:legacy_transcript) { described_class.new(Nokogiri::XML(File.read(Rails.root + "spec/test_support/ohms_xml/legacy/hanford_OH0139.xml")))}

    it "has parsed content" do
      footnotes_array = legacy_transcript.footnote_array

      expect(footnotes_array.length).to eq(2)
      expect(footnotes_array[0]).to eq "William E. Hanford (to E.I. DuPont de Nemours & Co.), \"Polyamides,\" U.S. Patent 2,281,576, issued 5 May 1942."
      expect(footnotes_array[1]).to eq "Howard N. and Lucille L. Sloane, A Pictorial History of American Mining: The adventure and drama of finding and extracting nature's wealth from the earth, from pre-Columbian times to the present (New York: Crown Publishers, Inc., 1970)."
    end
  end
end
