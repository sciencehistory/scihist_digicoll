require 'rails_helper'
describe OralHistoryContent do
  let(:work) { create(:work) }
  let(:oral_history_content) { work.create_oral_history_content }

  let(:work_with_oral_history_content) { create(:oral_history_work) }

  let(:m4a_path) { Rails.root + "spec/test_support/audio/5-seconds-of-silence.m4a" }

  describe "#set_combined_audio_m4a!" do
    it "can set" do
      oral_history_content.set_combined_audio_m4a!(File.open(m4a_path))

      expect(oral_history_content.changed?).to be(false)
      expect(oral_history_content.combined_audio_m4a).to be_present
      expect(oral_history_content.combined_audio_m4a.read).to eq(File.read(m4a_path, encoding: "BINARY"))
      expect(oral_history_content.combined_audio_m4a.size).to eq(File.size(m4a_path))

      expect(oral_history_content.combined_audio_m4a.original_filename).to eq("combined.m4a")
      expect(oral_history_content.combined_audio_m4a.mime_type).to eq("audio/mp4")

      expect(oral_history_content.combined_audio_m4a.id).to match(/#{work.id}\/combined_[a-f0-9]+\.m4a/)
    end

    describe "for failed save" do
      it "doesn't leave behind file in storage" do
        allow(oral_history_content).to receive(:save!).and_raise("mock error")

        expect {
          oral_history_content.set_combined_audio_m4a!(File.open(m4a_path))
        }.to raise_error("mock error")

        date_of_error = oral_history_content.
          combined_audio_derivatives_job_status_changed_at

        expect(oral_history_content.combined_audio_derivatives_job_status).to eq "failed"

        expect(date_of_error).to be_instance_of ActiveSupport::TimeWithZone

        time_since_error = Time.now.to_i - date_of_error.to_i
        expect(time_since_error).to be <= 600
        expect(oral_history_content.combined_audio_m4a).not_to be_present
      end
    end
  end


  describe "combined_audio_derivatives_job_status" do
    it "sets the date when you change the status" do
      oral_history_content.combined_audio_derivatives_job_status = 'started'
      oral_history_content.save!
      expect(oral_history_content.combined_audio_derivatives_job_status).to eq('started')
      date_changed = oral_history_content.combined_audio_derivatives_job_status_changed_at
      expect(date_changed).to be_instance_of ActiveSupport::TimeWithZone
      time_since_changed = Time.now.to_i - date_changed.to_i
      expect(time_since_changed).to be <= 600
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

  describe "auto-index of associated work" do
    around do |example|
      oral_history_content # trigger creation, then enable auto indexing callbacks
      original = Kithe.indexable_settings.disable_callbacks
      Kithe.indexable_settings.disable_callbacks = false

      example.run

      Kithe.indexable_settings.disable_callbacks = original
    end

    it "does not update_index if transcript did not change" do
      expect(oral_history_content.work).not_to receive(:update_index)
      oral_history_content.update(combined_audio_fingerprint: "fake")
    end

    it "does update_index if ohms_xml_text changed" do
      expect(oral_history_content.work).to receive(:update_index)
      oral_history_content.update(ohms_xml_text: File.open(Rails.root + "spec/test_support/ohms_xml/legacy/alyea_OH0010.xml"))
    end

    it "does update_index if searchable_transcript_source changed" do
      expect(oral_history_content.work).to receive(:update_index)
      oral_history_content.update(searchable_transcript_source: "fake")
    end
  end

  describe "No OHMS Transcript" do
    # ohms does a weird thing wehre it puts "No transcript." in an XML element, let's make sure
    # we're catching it.
    let(:oral_history_content) {
      work.create_oral_history_content(
        ohms_xml_text: File.read(Rails.root + "spec/test_support/ohms_xml/legacy/alyea_OH0010.xml")
      )
    }

    it "knows it" do
      expect(oral_history_content.has_ohms_transcript?).to be(false)
    end
  end


  describe "scopes" do
    let!(:ohms_oh) { create(:oral_history_work, :ohms_xml, :public_files, title: "OHMS OH")}
    let!(:immediate_oh) { create(:oral_history_work, :public_files, title: "Public OH") }
    let!(:needs_approval_oh) { create(:oral_history_work, :available_by_request, title: "Needs approval OH", available_by_request_mode: "manual_review")}
    let!(:upon_request_oh) { create(:oral_history_work, :available_by_request, title: "Automatic Approval OH", available_by_request_mode: "automatic") }
    let!(:private_oh) {
      create(:oral_history_work,
        title: "NOT available OH",
        members: [
          create(:asset, role: :portrait, published: true),
          create(:asset_with_faked_file, :pdf, role: :transcript, published: false)
        ]
      )
    }

    it "fetches ohms" do
      results = OralHistoryContent.with_ohms.to_a

      expect(results).to include(ohms_oh.oral_history_content)

      expect(results).not_to include(immediate_oh.oral_history_content)
      expect(results).not_to include(needs_approval_oh.oral_history_content)
      expect(results).not_to include(upon_request_oh.oral_history_content)
      expect(results).not_to include(private_oh.oral_history_content)
    end

    it "fetches immediate" do
      results = OralHistoryContent.available_immediate.to_a

      expect(results).to include(immediate_oh.oral_history_content)
      expect(results).to include(ohms_oh.oral_history_content)
      expect(results.count).to eq 2

      expect(results).not_to include(needs_approval_oh.oral_history_content)
      expect(results).not_to include(upon_request_oh.oral_history_content)
      expect(results).not_to include(private_oh.oral_history_content)
    end

    it "fetches upon_request" do
      results = OralHistoryContent.upon_request.to_a

      expect(results).to include(upon_request_oh.oral_history_content)

      expect(results).not_to include(ohms_oh.oral_history_content)
      expect(results).not_to include(immediate_oh.oral_history_content)

      expect(results).not_to include(needs_approval_oh.oral_history_content)
      expect(results).not_to include(private_oh.oral_history_content)
    end

    it "fetches (upon_request OR immediate)" do
      # have to do crazy thing with removing then adding DISTICNT to get it to work
      results = OralHistoryContent.available_immediate.or( OralHistoryContent.upon_request ).to_a

      expect(results).to include(upon_request_oh.oral_history_content)
      expect(results).to include(ohms_oh.oral_history_content)
      expect(results).to include(immediate_oh.oral_history_content)

      expect(results).not_to include(needs_approval_oh.oral_history_content)
      expect(results).not_to include(private_oh.oral_history_content)
    end

    it "fetches needs_approval" do
      results = OralHistoryContent.needs_approval.to_a

      expect(results).to include(needs_approval_oh.oral_history_content)


      expect(results).not_to include(upon_request_oh.oral_history_content)
      expect(results).not_to include(ohms_oh.oral_history_content)
      expect(results).not_to include(immediate_oh.oral_history_content)
      expect(results).not_to include(private_oh.oral_history_content)
    end

    it "fetches fully_embarboed" do
      results = OralHistoryContent.fully_embargoed.to_a

      expect(results).to include(private_oh.oral_history_content)

      expect(results).not_to include(needs_approval_oh.oral_history_content)
      expect(results).not_to include(upon_request_oh.oral_history_content)
      expect(results).not_to include(ohms_oh.oral_history_content)
      expect(results).not_to include(immediate_oh.oral_history_content)
    end

    it "fetches all except fully embargoed" do
      results = OralHistoryContent.all_except_fully_embargoed.to_a

      expect(results).to include(needs_approval_oh.oral_history_content)
      expect(results).to include(upon_request_oh.oral_history_content)
      expect(results).to include(ohms_oh.oral_history_content)
      expect(results).to include(immediate_oh.oral_history_content)

      expect(results).not_to include(private_oh.oral_history_content)
    end
  end
end
