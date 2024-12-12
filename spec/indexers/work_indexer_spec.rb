require 'rails_helper'

describe WorkIndexer do
  let(:work) { create(:work, :with_complete_metadata) }

  let(:no_members_work) do
    create(:public_work, members: [])
  end

  # See https://github.com/sciencehistory/scihist_digicoll/issues/2585




  describe "box and folder" do
    let(:container_info) do
      Work::PhysicalContainer.new({"box"=>"1", "folder"=>"3"})
    end
    let(:work_2) { create(:work, physical_container: container_info) }

    it "does not index this metadata unless there are digits" do
      output_hash = WorkIndexer.new.map_record(work)
      expect(output_hash["box_isim"]).to eq nil
      expect(output_hash["folder_isim"]).to eq nil
    end

    it "indexes the box and folder" do
      output_hash = WorkIndexer.new.map_record(work_2)
      expect(output_hash["box_isim"]).to eq ["1"]
      expect(output_hash["folder_isim"]).to eq ["3"]
    end

    describe "more than one box or folder associated with the work" do
      let(:container_info) do
        Work::PhysicalContainer.new({"box"=>"1 - 2", "folder"=>"3 - 4"})
      end
      it "splits multiple boxes / folders into two integers so they can be matched" do
        output_hash = WorkIndexer.new.map_record(work_2)
        expect(output_hash["box_isim"]).to eq ["1", "2"]
        expect(output_hash["folder_isim"]).to eq ["3", "4"]
      end
    end
  end

  it "indexes" do
    output_hash = WorkIndexer.new.map_record(work)
    expect(output_hash).to be_present

    expect(output_hash["model_pk_ssi"]).to eq([work.id])
  end

  it "doesn't raise if members are absent" do
    output_hash = WorkIndexer.new.map_record(no_members_work)
    expect(output_hash).to be_present
    expect(output_hash["model_pk_ssi"]).to eq([no_members_work.id])
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
  # BOX AND FOLDER USED TO GO HERE



  # See https://github.com/sciencehistory/scihist_digicoll/issues/2585
  describe "box and folder" do
    let(:container_info) do
      Work::PhysicalContainer.new({"box"=>"1", "folder"=>"3"})
    end
    let(:work_2) { create(:work, physical_container: container_info) }

    it "does not index this metadata unless there are digits" do
      output_hash = WorkIndexer.new.map_record(work)
      expect(output_hash["box_isim"]).to eq nil
      expect(output_hash["folder_isim"]).to eq nil
    end

    it "indexes the box and folder" do
      output_hash = WorkIndexer.new.map_record(work_2)
      expect(output_hash["box_isim"]).to eq ["1"]
      expect(output_hash["folder_isim"]).to eq ["3"]
    end

    describe "more than one box or folder associated with the work" do
      let(:container_info) do
        Work::PhysicalContainer.new({"box"=>"1 - 2", "folder"=>"3 - 4"})
      end
      it "splits multiple boxes / folders into two integers so they can be matched" do
        output_hash = WorkIndexer.new.map_record(work_2)
        expect(output_hash["box_isim"]).to eq ["1", "2"]
        expect(output_hash["folder_isim"]).to eq ["3", "4"]
      end
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

    describe 'dates' do
      around do |example|
        freeze_time do
          example.run
        end
      end

      it "indexes created, modified, and published dates" do
        output_hash = WorkIndexer.new.map_record(no_members_work)
        expect(Time.parse(output_hash["date_created_dtsi"  ].first)).to eq Time.now
        expect(Time.parse(output_hash["date_modified_dtsi" ].first)).to eq Time.now
        expect(Time.parse(output_hash["date_published_dtsi"].first)).to eq Time.now
      end
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

      it "has no searchable_fulltext_en" do
        output_hash = WorkIndexer.new.map_record(work)
        expect(output_hash["searchable_fulltext_en"]).to eq(nil)
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
        expect(output_hash["searchable_fulltext_en"]).to eq(["searchable_transcript_source"])
      end
    end

    describe "only searchable_transcript_source" do
      let(:oral_history_content) { OralHistoryContent.new(searchable_transcript_source: "searchable_transcript_source") }

      it "indexes searchable_transcript_source" do
        output_hash = WorkIndexer.new.map_record(work)
        expect(output_hash["searchable_fulltext_en"]).to eq(["searchable_transcript_source"])
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

        expect(output_hash["searchable_fulltext_en"]).to be_present
        expect(output_hash["searchable_fulltext_en"].first).to start_with("[untranscribed pre-interview discussion]")
        # exactly how many entries depends on how many toc entries have synopsis, keywords, etc.
        expect(output_hash["searchable_fulltext_en"].length).to be > (1 + index_toc_entries_count)
      end

      it "indexes ToC components" do
        output_hash = WorkIndexer.new.map_record(work)

        joined_keywords = work.oral_history_content.ohms_xml.index_points.collect { |ip| ip.all_keywords_and_subjects.join("; ") }.collect(&:presence).compact

        expect(output_hash["searchable_fulltext_en"]).to include(*joined_keywords)
        expect(output_hash["searchable_fulltext_en"]).to include(*work.oral_history_content.ohms_xml.index_points.collect(&:title).collect(&:presence).compact)
        expect(output_hash["searchable_fulltext_en"]).to include(*work.oral_history_content.ohms_xml.index_points.collect(&:synopsis).collect(&:presence).compact)

        # keywords and subjects should also be in the text3_tesim field we use for subjects,
        # for greater boosting
        all_keywords = work.oral_history_content.ohms_xml.index_points.collect(&:all_keywords_and_subjects).flatten.compact.uniq
        expect(all_keywords - output_hash["text3_tesim"]).to be_empty
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
        expect(output_hash["searchable_fulltext_en"].length).to eq(1)
        output = output_hash["searchable_fulltext_en"].first

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
        position: page,
        published: true
        ) }
    end

    # transcription : en
    # translation   : en
    let(:english_only_work) do
      create(:public_work, language: ['English'], members: assets )
    end

    # transcription : agnostic
    # translation   : en
    let(:bilingual_work) do
      create(:public_work, language: ['English', 'German'], members: assets)
    end

    # transcription : de
    # translation   : en
    let(:german_only_work) do
      create(:public_work, language: ['German'], members: assets )
    end

    let(:nil_members_work) do
      create(:public_work, members: [])
    end

    before do
      allow(nil_members_work).to receive(:members).and_return(nil)
    end

    describe "works in various languages" do
      let(:output_hash) { WorkIndexer.new.map_record(language_test_work) }
      let(:english) { output_hash["searchable_fulltext_en"] }
      let(:german)  { output_hash["searchable_fulltext_de"] }
      let(:unsure)  { output_hash["searchable_fulltext_language_agnostic"] }
      describe "text known to be in English" do
        let(:language_test_work) { english_only_work }
        it "goes in searchable_fulltext_en" do
          expect(english).to eq(["transl_1", "transl_2", "transl_3", "transc_1", "transc_2", "transc_3"])
          expect(german).to be_nil
          expect(unsure).to be_nil
        end
      end
      describe "text known to be in German" do
        let(:language_test_work) { german_only_work }
        it "goes in searchable_fulltext_de" do
          expect(german).to eq(["transc_1", "transc_2", "transc_3"])
          expect(english).to eq(["transl_1", "transl_2", "transl_3"])
          expect(unsure).to be_nil
        end
      end
      describe "text in either English or German or something else" do
        let(:language_test_work) { bilingual_work }
        it "goes in searchable_fulltext_language_agnostic" do
          expect(german).to be_nil
          expect(unsure).to eq(["transc_1", "transc_2", "transc_3"])
          expect(english).to eq(["transl_1", "transl_2", "transl_3"])
        end
      end
      describe "no assets" do
        let(:language_test_work) { no_members_work }
        it "results in nil indexes" do
          expect(english).to be_nil
          expect(german).to  be_nil
          expect(unsure).to  be_nil
        end
      end
      describe "nil assets" do
        let(:language_test_work) { nil_members_work }
        it "results in nil indexes" do
          expect(english).to be_nil
          expect(german).to  be_nil
          expect(unsure).to  be_nil
        end
      end
    end

    describe "with OCR" do
      let(:assets) do
        [3,2,1].map { |page| create(
          :asset,
          position: page,
          published: true,
          hocr: hocr
          ) }
      end

      let (:hocr) { File.read('spec/test_support/hocr_xml/hocr.xml')}
      let(:expected_hocr) {
        ["CAUTION All units must be connected as above before the Power Supply is connected."] * 3
      }

      let(:output_hash) { WorkIndexer.new.map_record(language_test_work) }
      let(:english) { output_hash["searchable_fulltext_en"] }
      let(:german)  { output_hash["searchable_fulltext_de"] }
      let(:unsure)  { output_hash["searchable_fulltext_language_agnostic"] }
      describe "text known to be in English" do
        let(:language_test_work) { create(:public_work, language: ['English'], members: assets ) }
        it "goes in searchable_fulltext_en" do
          expect(english).to eq(expected_hocr)
          expect(german).to be_nil
          expect(unsure).to be_nil
        end
      end
      describe "text known to be in German" do
        let(:language_test_work) { create(:public_work, language: ['German'], members: assets ) }
        it "goes in searchable_fulltext_de" do
          expect(german).to eq(expected_hocr)
          expect(english).to be_nil
          expect(unsure).to be_nil
        end
      end
      describe "bilingual text" do
        let(:language_test_work) { create(:public_work, language: ['English', 'German'], members: assets) }
        it "goes in searchable_fulltext_language_agnostic" do
          expect(german).to be_nil
          expect(unsure).to eq(expected_hocr)
          expect(english).to be_nil
        end
      end
    end

    describe "with unpublished assets" do
      let(:assets) do
        [3,2,1].map { |page| create(
          :asset,
          transcription: "transc_#{page}",
          english_translation: "transl_#{page}",
          position: page,
          published: false
          ) }
      end
      it "does not index" do
        output_hash = WorkIndexer.new.map_record(bilingual_work)

        expect(output_hash["searchable_fulltext_language_agnostic"]).to be_blank
        expect(output_hash["searchable_fulltext_en"]).to be_blank
      end
    end
  end
end
