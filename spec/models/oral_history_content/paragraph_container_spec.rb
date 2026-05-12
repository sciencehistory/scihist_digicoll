require 'rails_helper'

describe OralHistoryContent::ParagraphContainer do
  describe "#extracted_pdf_paragraphs" do
    # has two embedded inteviews, three audio files total, requires timestamp arithmatic
    let(:pdf_file_path) { Rails.root + "spec/test_support/pdf/oh/glusker_2022_sequence_timestamps_example.pdf" }

    # At the moment we have to actually create this in DB due to how some helper
    # services require it, it is slow, sorry.

    let(:pdf_asset) do
      # have to create in db so we can add derivative
      create(:asset_with_faked_file, :pdf,
        published: true,
        faked_file: File.open(pdf_file_path),
        faked_md5: Digest::MD5.hexdigest("fake"),
        title: 'transcript',
        role: "transcript",
        faked_derivatives: {}
      ).tap do |asset|
        # create a real one? Slow but real end to end test. Will save to DB again.
        asset.create_derivatives(only: :extracted_pdf_text_json)
      end
    end

    let(:mp3_asset) do
      create(:asset_with_faked_file, :mp3,
          title: "audio_recording.mp3",
          published: true,
          faked_duration_seconds: 44.minutes,
          faked_derivatives: {} )
    end

    let(:mp3_asset2) do
      create(:asset_with_faked_file, :mp3,
          title: "audio_recording.mp3",
          published: true,
          faked_duration_seconds: 55.minutes,
          faked_derivatives: {} )
    end

    let(:mp3_asset3) do
      create(:asset_with_faked_file, :mp3,
          title: "audio_recording.mp3",
          published: true,
          faked_duration_seconds: 12.minutes,
          faked_derivatives: {} )
    end

    let(:work) do
      create(:oral_history_work, members: [
        pdf_asset,
        mp3_asset,
        mp3_asset2,
        mp3_asset3
      ])
    end

    let(:oral_history_content) { work.oral_history_content }

    it "end to end tests: creation, serialization, freshness" do
      container = OralHistoryContent::ParagraphContainer.create(
        oral_history_content: oral_history_content,
      )
      expect(oral_history_content.extracted_pdf_paragraphs).to be_present

      oral_history_content.reload

      expect(oral_history_content.extracted_pdf_paragraphs.paragraphs).to all(be_kind_of(OralHistoryContent::Paragraph))
      expect(oral_history_content.extracted_pdf_paragraphs.fresh?(oral_history_content: oral_history_content)).to be true

      expect(oral_history_content.extracted_pdf_paragraphs.logical_page_number_offset).to eq 0

      # changing pdf md5 makes not fresh anymore. LOTS of saves to DB and reloads here, very
      # bad performance, but good semantics for now.
      old_pdf_md5 = pdf_asset.file_metadata["md5"]
      pdf_asset.file_attacher.add_metadata("md5" => "bad")
      pdf_asset.file_attacher.write
      pdf_asset.save!
      oral_history_content.reload
      expect(oral_history_content.extracted_pdf_paragraphs.fresh?(
        oral_history_content: oral_history_content
      )).to be false

      pdf_asset.file_attacher.add_metadata("md5" => old_pdf_md5)
      pdf_asset.file_attacher.write
      pdf_asset.save!
      oral_history_content.reload

      expect(oral_history_content.extracted_pdf_paragraphs.fresh?(oral_history_content: oral_history_content)).to be true

      # changing an audio file fingerprint makes it not fresh anymore, as
      # start time offsets might be different.
      mp3_asset.file_attacher.add_metadata("sha512" => "bad")
      mp3_asset.file_attacher.write
      mp3_asset.save!
      oral_history_content.reload

      expect(oral_history_content.extracted_pdf_paragraphs.fresh?(oral_history_content: oral_history_content)).to be false
    end

    describe "with warnings" do
      # missing mp3 assets, so there will be a sync warning
      let(:work) do
        create(:oral_history_work, members: [
          pdf_asset,
          mp3_asset,
        ])
      end

      it "stores warnings" do
        container = OralHistoryContent::ParagraphContainer.create(
          oral_history_content: oral_history_content,
          allow_failure_to_sync: true
        )

        expect(container.warnings).to be_present
        expect(container.warnings).to include(/Failed to sync some timestamps/)
      end
    end
  end
end
