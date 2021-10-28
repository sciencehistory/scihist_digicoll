require 'rails_helper'

describe WorkIndexer do
  let(:work) { create(:work, :with_complete_metadata) }

  let(:no_members) do
    create(:public_work, members: [])
  end

  it "indexes" do
    output_hash = WorkIndexer.new.map_record(work)
    expect(output_hash).to be_present

    expect(output_hash["model_pk_ssi"]).to eq([work.id])
  end

  it "doesn't raise if members are absent" do
    output_hash = WorkIndexer.new.map_record(no_members)
    expect(output_hash).to be_present
    expect(output_hash["model_pk_ssi"]).to eq([no_members.id])
  end

  describe "with containers" do
    let(:collection1) {  create(:collection) }
    let(:collection2) {  create(:collection) }
    let(:work) {  create(:work, contained_by: [collection1, collection2] ) }

    it "indexes collection ids" do
      work.contains_contained_by.reload # not sure what we're working around, but okay
      output_hash = WorkIndexer.new.map_record(work)

      expect(output_hash["collection_id_ssim"]).to match [collection1.id, collection2.id]
    end
  end

  describe "desription with html" do
    let(:work) { create(:work, description: "This originally had <b>html</b> and <a href='http://example.com'>stuff</a>.") }
    it "is stripped to plaintext in index" do
      output_hash = WorkIndexer.new.map_record(work)
      expect(output_hash["description_text4_tesim"]).to eq ["This originally had html and stuff."]
    end
  end

  describe "oral history" do
    let(:work) { create(:oral_history_work, format: ['text']) }

    it "indexes interviewer_facet" do
      output_hash = WorkIndexer.new.map_record(work)
      expect(output_hash["interviewer_facet"]).not_to eq(nil)
    end

    it "indexes biographical information" do
      output_hash = WorkIndexer.new.map_record(work)

      boosted_values = (work.oral_history_content.interviewee_biographies.collect(&:school).flatten.collect(&:institution) +
        work.oral_history_content.interviewee_biographies.collect(&:job).flatten.collect(&:institution) +
        work.oral_history_content.interviewee_biographies.collect(&:honor).flatten.collect(&:honor)).uniq
      expect(output_hash["text3_tesim"]).to match(boosted_values)

      # and a sampling of some others
      expect(output_hash["text_no_boost_tesim"]).to include(
        work.oral_history_content.interviewee_biographies.first.birth.displayable_values.join(", ")
      )
    end

    it "indexes biographical to institution facet" do
      output_hash = WorkIndexer.new.map_record(work)

      institutions = (work.oral_history_content.interviewee_biographies.collect(&:school).flatten.collect(&:institution) +
        work.oral_history_content.interviewee_biographies.collect(&:job).flatten.collect(&:institution)).uniq

      expect(output_hash["oh_institution_facet"]).to match_array(institutions)

      expect(output_hash["oh_birth_country_facet"]).to eq(work.oral_history_content.interviewee_biographies.collect(&:birth).flatten.collect(&:country_name))
    end

    describe "features facet" do
      it "has transcript value" do
        output_hash = WorkIndexer.new.map_record(work)
        expect(output_hash["oh_feature_facet"]).to eq(["Transcript"])
      end

      describe "with audio and ohms xml" do
        let(:work) { create(:oral_history_work, :ohms_xml, format: ['text', 'sound']) }

        it "has facet values" do
          output_hash = WorkIndexer.new.map_record(work)
          expect(output_hash["oh_feature_facet"]).to match_array(["Audio recording", "Synchronized audio", "Transcript"])
        end
      end
    end
  end

  describe "with oral history transcript" do
    let(:work) { create(:oral_history_work, oral_history_content: oral_history_content) }

    describe "ohms xml with missing transcript" do
      # this one has missing transcript...
      let(:ohms_xml) { File.read(Rails.root + "spec/test_support/ohms_xml/empty_ohms.xml") }

      let(:oral_history_content) { OralHistoryContent.new(ohms_xml_text: ohms_xml) }

      it "has no searchable_fulltext" do
        output_hash = WorkIndexer.new.map_record(work)
        expect(output_hash["searchable_fulltext"]).to eq(nil)
      end
    end


    describe "ohms xml with missing transcript and plaintext" do
      # this one has missing transcript...
      let(:ohms_xml) { File.read(Rails.root + "spec/test_support/ohms_xml/empty_ohms.xml") }

      let(:oral_history_content) { OralHistoryContent.new(
                                    searchable_transcript_source: "searchable_transcript_source",
                                    ohms_xml_text: ohms_xml) }
      it "indexes only searchable_transcript_source" do
        output_hash = WorkIndexer.new.map_record(work)
        expect(output_hash["searchable_fulltext"]).to eq(["searchable_transcript_source"])
      end
    end

    describe "only searchable_transcript_source" do
      let(:oral_history_content) { OralHistoryContent.new(searchable_transcript_source: "searchable_transcript_source") }

      it "indexes searchable_transcript_source" do
        output_hash = WorkIndexer.new.map_record(work)
        expect(output_hash["searchable_fulltext"]).to eq(["searchable_transcript_source"])
      end
    end

    describe "complete ohms_xml, plus plaintext searchable" do
      let(:ohms_xml) { File.read(Rails.root + "spec/test_support/ohms_xml/smythe_OH0042.xml") }
      let(:oral_history_content) { OralHistoryContent.new(
                                  searchable_transcript_source: "searchable_transcript_source",
                                  ohms_xml_text: ohms_xml) }

      it "uses ohms_xml" do
        index_toc_entries_count = work.oral_history_content.ohms_xml.index_points.count { |i| i.keywords.present? }

        output_hash = WorkIndexer.new.map_record(work)

        expect(output_hash["searchable_fulltext"]).to be_present
        expect(output_hash["searchable_fulltext"].first).to start_with("[untranscribed pre-interview discussion]")
        expect(output_hash["searchable_fulltext"].length).to eq(1 + index_toc_entries_count)
      end

      it "indexes ToC keywords" do
        output_hash = WorkIndexer.new.map_record(work)
        some_keywords = work.oral_history_content.ohms_xml.index_points.second.keywords.join("; ")
        expect(output_hash["searchable_fulltext"]).to include(some_keywords)
      end
    end

    describe "with footnote tags" do
      let(:ohms_xml) do
        <<~EOS
        <?xml version="1.0" encoding="UTF-8"?>
        <ROOT xmlns="https://www.weareavp.com/nunncenter/ohms" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xsi:schemaLocation="https://www.weareavp.com/nunncenter/ohms/ohms.xsd">
        <record id="00089262" dt="2020-05-28">
          <transcript>
            A claim [[footnote]]1[[/footnote]]

            [[footnotes]]
              [[note]]A citation[[/note]]
            [[/footnotes]]
          </transcript>
        </record>
        </ROOT>
        EOS
      end
      let(:oral_history_content) { OralHistoryContent.new(ohms_xml_text: ohms_xml) }

      it "strips markup appropriately" do
        output_hash = WorkIndexer.new.map_record(work)
        expect(output_hash["searchable_fulltext"].length).to eq(1)
        output = output_hash["searchable_fulltext"].first

        expect(output.gsub(/\W+/, ' ').strip).to eq("A claim A citation")
      end
    end
  end

  describe "with transcription and translation" do
    let(:assets) do
      [3,2,1].map { |page| create(
        :asset,
        transcription: "transc_#{page}",
        english_translation: "transl_#{page}",
        position: page
        ) }
    end
    let(:english_only) do
      create(:public_work, language: ['en'], members: assets )
    end
    let(:bilingual) do
      create(:public_work, language: ['en', 'de'], members: assets)
    end
    let(:german_only) do
      create(:public_work, language: ['de'], members: assets )
    end

    let(:nil_members) do
      create(:public_work, members: [])
    end

    before do
      allow(nil_members).to receive(:members).and_return(nil)
    end

    it "indexes text known to be English in searchable_fulltext" do
      output_hash = WorkIndexer.new.map_record(english_only)
      english  = output_hash["searchable_fulltext"]
      might_not_be_english = output_hash["searchable_fulltext_language_agnostic"]
      expect(english).to eq(["transl_1", "transl_2", "transl_3", "transc_1", "transc_2", "transc_3"])
      expect(might_not_be_english).to be_nil
    end

    it "indexes transcriptions in searchable_fulltext_language_agnostic if we know the work isn't all in English" do
      [german_only, bilingual].each do |work_with_translations|
        output_hash = WorkIndexer.new.map_record(work_with_translations)
        english  = output_hash["searchable_fulltext"]
        might_not_be_english = output_hash["searchable_fulltext_language_agnostic"]
        expect(english).to eq( ["transl_1", "transl_2", "transl_3"])
        expect(might_not_be_english).to eq(["transc_1", "transc_2", "transc_3"])
      end
    end

    it "correctly handles items without any assets" do
      [nil_members, no_members].each do |work|
        output_hash = WorkIndexer.new.map_record(work)
        english  = output_hash["searchable_fulltext"]
        might_not_be_english = output_hash["searchable_fulltext_language_agnostic"]
        expect(english).to be_nil
        expect(might_not_be_english).to be_nil
      end
    end

  end

end
