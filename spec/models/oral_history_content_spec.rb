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

  describe "No OHMS Transcript" do
    # ohms does a weird thing wehre it puts "No transcript." in an XML element, let's make sure
    # we're catching it.
    let(:oral_history_content) {
      work.create_oral_history_content(
        ohms_xml_text: File.read(Rails.root + "spec/test_support/ohms_xml/alyea_OH0010.xml")
      )
    }

    it "knows it" do
      expect(oral_history_content.has_ohms_transcript?).to be(false)
    end
  end


  describe OralHistoryContent::OhmsXml do
    let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/duarte_OH0344.xml"}
    let(:ohms_xml) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path))}
    let(:ohms_xml_path_with_footnotes) { Rails.root + "spec/test_support/ohms_xml/hanford_OH0139.xml"}
    let(:ohms_xml_with_footnotes) { OralHistoryContent::OhmsXml.new(File.read(ohms_xml_path_with_footnotes))}


    describe "#sync_timecodes" do
      it "are as expected" do
        # we'll just check a sampling, we have one-second interval granularity in XML
        expect(ohms_xml.sync_timecodes.count).to eq(28)
        expect(ohms_xml.sync_timecodes[13]).to  eq([{:line_number=>"13", :seconds=>60,  :word_number=>3}])
        expect(ohms_xml.sync_timecodes[19]).to  eq([{:line_number=>"19", :seconds=>120, :word_number=>14}])
        expect(ohms_xml.sync_timecodes[308]).to eq([{:line_number=>"308", :seconds=>1680, :word_number=>2}])
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

      describe "with hyperlinks" do
        let(:ohms_xml_path) { Rails.root + "spec/test_support/ohms_xml/index_hyperlinks_example.xml" }

        it "get parsed" do
          expect(ohms_xml.index_points.first.hyperlinks.collect(&:to_h)).to eq([
            {:href=>"https://digital.sciencehistory.org/works/cf95jc49c", :text=>"Oral history interview with Hubert N. Alyea"},
            {:href=>"https://digital.sciencehistory.org/works/g445cf063", :text=>"Oral history interview with William E. Hanford"},
            {:href=>"https://digital.sciencehistory.org/works/1n79h560c", :text=>"Oral history interview with Malcolm M. Renfrew"}
          ])
        end
      end
    end

    describe "#transcript_lines" do
      it "strips footnote section from the text" do
        expect(ohms_xml_with_footnotes.transcript_lines).to be_present
        all_text = ohms_xml_with_footnotes.transcript_lines.join("\n")
        expect(all_text).not_to match(%r{\[\[/?footnotes\]\]})
      end
      it "correctly outputs an empty array of footnotes when none are present" do
        expect(ohms_xml.transcript_lines).to be_present
        expect(ohms_xml.footnote_array).to eq []
      end
      it "keeps references to the footnotes in the text, if they are present" do
        all_text = ohms_xml_with_footnotes.transcript_lines.join("\n")
        expect(all_text).to match(/\[\[footnote\]\]1\[\[\/footnote\]\]/)
        expect(all_text).to match(/\[\[footnote\]\]2\[\[\/footnote\]\]/)
      end
      it "makes footnotes available via the footnote array" do
        expect(ohms_xml_with_footnotes.footnote_array.length).to eq 2
        expect(ohms_xml_with_footnotes.footnote_array[0]).to match(/Polyamides/)
        expect(ohms_xml_with_footnotes.footnote_array[1]).to match(/Lucille/)
      end

      it "makes footnotes available via the footnote array" do
        expect(ohms_xml_with_footnotes.footnote_array.length).to eq 2
        expect(ohms_xml_with_footnotes.footnote_array[0]).to match(/Polyamides/)
        expect(ohms_xml_with_footnotes.footnote_array[1]).to match(/Lucille/)
      end
    end
  end
end
