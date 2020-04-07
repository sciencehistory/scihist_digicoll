require 'rails_helper'

describe OralHistoryContent do
  let(:work) { create(:work) }
  let(:oral_history_content) { work.create_oral_history_content }
  let(:mp3_path) { Rails.root + "spec/test_support/audio/ice_cubes.mp3" }
  let(:webm_path) { Rails.root + "spec/test_support/audio/smallest_webm.webm" }

  describe "#set_combined_audio_mp3!" do
    it "can set" do
      oral_history_content.set_combined_audio_mp3!(File.open(mp3_path))

      expect(oral_history_content.changed?).to be(false)
      expect(oral_history_content.combined_audio_mp3).to be_present
      expect(oral_history_content.combined_audio_mp3.read).to eq(File.read(mp3_path, encoding: "BINARY"))
      expect(oral_history_content.combined_audio_mp3.size).to eq(File.size(mp3_path))

      expect(oral_history_content.combined_audio_mp3.original_filename).to eq("combined.mp3")
      expect(oral_history_content.combined_audio_mp3.mime_type).to eq("audio/mpeg")

      expect(oral_history_content.combined_audio_mp3.id).to match(/#{work.id}\/combined_[a-f0-9]+\.mp3/)
    end

    describe "for failed save" do
      it "doesn't leave behind file in storage" do
        allow(oral_history_content).to receive(:save!).and_raise("mock error")

        expect {
          oral_history_content.set_combined_audio_mp3!(File.open(mp3_path))
        }.to raise_error("mock error")

        expect(oral_history_content.changed?).to be(false)
        expect(oral_history_content.combined_audio_mp3).not_to be_present
      end
    end
  end

  describe "#set_combined_audio_webm!" do
    it "can set" do
      oral_history_content.set_combined_audio_webm!(File.open(webm_path))

      expect(oral_history_content.changed?).to be(false)
      expect(oral_history_content.combined_audio_webm).to be_present
      expect(oral_history_content.combined_audio_webm.read).to eq(File.read(webm_path, encoding: "BINARY"))
      expect(oral_history_content.combined_audio_webm.size).to eq(File.size(webm_path))
      expect(oral_history_content.combined_audio_webm.original_filename).to eq("combined.webm")
      expect(oral_history_content.combined_audio_webm.mime_type).to eq("audio/webm")
    end
  end

  describe "work#oral_history_content!" do
    describe "without existing sidecar" do
      it "creates one" do
        expect(work.oral_history_content).to be_nil
        result = work.oral_history_content!

        expect(result).to be_present
        expect(work.oral_history_content).to be_present
        expect(result).to equal(work.oral_history_content)
      end
    end

    describe "with existing content" do
      it "returns existing" do
        existing = oral_history_content
        expect(existing).to equal(work.oral_history_content)

        result = work.oral_history_content!
        expect(result).to equal(work.oral_history_content)
        expect(result).to equal(existing)
      end
    end

    describe "with concurrently created content" do
      it "is handles" do
        # pre-conditions
        expect(work.oral_history_content).to be_nil
        concurrent = OralHistoryContent.create!(work_id: work.id)
        expect(work.oral_history_content).to be_nil

        result = work.oral_history_content!
        expect(result.id).to equal(concurrent.id)
      end
    end
  end


  describe OralHistoryContent::OhmsXml do
    let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/duarte_OH0344.xml"}
    let(:ohms_xml) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path))}

    describe "#sync_timecodes" do
      it "are as expected" do
        # we'll just check a sampling, we have one-second interval granularity in XML
        expect(ohms_xml.sync_timecodes.count).to eq(28)
        expect(ohms_xml.sync_timecodes[13]).to eq({:word_number=>3, :seconds=>60, line_number: 13})
        expect(ohms_xml.sync_timecodes[19]).to eq({:word_number=>14, :seconds=>120, :line_number=>19})

        expect(ohms_xml.sync_timecodes[308]).to eq({:word_number=>2, :seconds=>1680, :line_number=>308})
      end
    end

    describe "#index_points" do
      it "are as expected" do
        expect(ohms_xml.index_points).to be_present
        expect(ohms_xml.index_points.count).to eq(7)

        # spot check one
        expect(ohms_xml.index_points.second.title).to eq("Growing up with Gordon Moore")
        expect(ohms_xml.index_points.second.timestamp).to eq(212)
        expect(ohms_xml.index_points.second.synopsis).to eq("Gordon Moore’s mother Myra. Gordon Moore moving to Redwood City. Getting into trouble with a wagon. Gordon Moore visiting Pescadero. Gordon Moore tinkering. Grammar school. Sequoia High School. Friends. Gordon Moore as a student.")
        expect(ohms_xml.index_points.second.partial_transcript).to eq("BROCK:  That general store was just down the street, not too far from your family’s tavern?\nDUARTE:  Yes.  The general store is called Muzzi’s now.")
        expect(ohms_xml.index_points.second.keywords).to eq(["Azores", "Gordon E. Moore", "Half Moon Bay", "Pescadero", "ranching", "San Mateo", "sheriff", "Walter E. Moore", "whaling", "Williamson family"])
      end
    end

    describe "#transcript_lines" do
      # an XML with footnotes so we can test them being stripped
      let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml"}

      it "strips footnotes" do
        expect(ohms_xml.transcript_lines).to be_present

        all_text = ohms_xml.transcript_lines.join("\n")

        expect(all_text).not_to match(%r{\[\[/?footnote\]\]})
        expect(all_text).not_to match(%r{\[\[/?footnotes\]\]})

        # with footnote omitted:
        expect(all_text).to include("mail them to get a patent.\n")
      end
    end
  end
end
