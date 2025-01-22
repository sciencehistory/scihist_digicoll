require 'rails_helper'

describe OralHistoryContent::OhmsXml::LegacyTranscript do
  let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/duarte_OH0344.xml"}
  let(:legacy_transcript) { described_class.new(Nokogiri::XML(File.read(ohms_xml_path)))}
  let(:ohms_xml_path_with_footnotes) { Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml"}
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

  describe "#transcript_lines" do
    it "strips footnote section from the text" do
      expect(legacy_transcript_with_footnotes.transcript_lines).to be_present
      all_text = legacy_transcript_with_footnotes.transcript_lines.join("\n")
      expect(all_text).not_to match(%r{\[\[/?footnotes\]\]})
    end
    it "correctly outputs an empty array of footnotes when none are present" do
      expect(legacy_transcript.transcript_lines).to be_present
      expect(legacy_transcript.footnote_array).to eq []
    end
    it "keeps references to the footnotes in the text, if they are present" do
      all_text = legacy_transcript_with_footnotes.transcript_lines.join("\n")
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
    let(:legacy_transcript) { described_class.new(Nokogiri::XML(File.read(Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml")))}

    it "has parsed content" do
      footnotes_array = legacy_transcript.footnote_array

      expect(footnotes_array.length).to eq(2)
      expect(footnotes_array[0]).to eq "William E. Hanford (to E.I. DuPont de Nemours & Co.), \"Polyamides,\" U.S. Patent 2,281,576, issued 5 May 1942."
      expect(footnotes_array[1]).to eq "Howard N. and Lucille L. Sloane, A Pictorial History of American Mining: The adventure and drama of finding and extracting nature's wealth from the earth, from pre-Columbian times to the present (New York: Crown Publishers, Inc., 1970)."
    end
  end



end
