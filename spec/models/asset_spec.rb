require 'rails_helper'

describe Asset do
  describe ".all_derivative_count" do
    let!(:assets) { [create(:asset_with_faked_file), create(:asset_with_faked_file)]}

    it "returns good count" do
      expected = assets.collect { |a| a.file_derivatives.count }.sum

      expect(expected).to be > 0
      expect(Asset.all_derivative_count).to eq(expected)
    end
  end

  describe "initial checksum creation", queue_adapter: :inline do
    let!(:asset) { create(:asset, :inline_promoted_file) }
    it "checks the asset after storing it" do
      expect(asset.fixity_checks.count).to eq 1
    end
  end

  describe "restricted derivatives", queue_adapter: :inline do
    let(:sample_file_location) {  Rails.root + "spec/test_support/images/20x20.png" }
    let(:asset) { create(:asset, derivative_storage_type: "restricted") }
    it "are stored in restricted derivatives location" do
      asset.file = File.open(sample_file_location)
      asset.save!
      asset.reload

      derivatives = asset.file_derivatives.values

      expect(derivatives).to all(satisfy { |d| d.storage_key == :restricted_kithe_derivatives })
      expect(asset.derivatives_in_correct_storage_location?).to be(true)
    end


    describe "starting out public", queue_adapter: :test do
      let(:asset) { create(:asset_with_faked_file) } # this creates faked derivatives too

      it "kicks off ensure derivatives storage job when storage type changed" do
        expect {
          asset.update!(derivative_storage_type: "restricted")
        }.to have_enqueued_job(EnsureCorrectDerivativesStorageJob)
      end
    end

    describe "with derivatives in wrong location" do
      let(:asset) do
        # create one with no derivatives
        a = create(:asset_with_faked_file,
          derivative_storage_type: "restricted",
          faked_derivatives: {})

        derivatives_on_public_storage = {
          "thumb_small" => a.file_attacher.upload_derivative("thumb_small", File.open(sample_file_location), storage: :kithe_derivatives, delete: false),
          "thumb_large" => a.file_attacher.upload_derivative("thumb_large", File.open(sample_file_location), storage: :kithe_derivatives, delete: false),
        }

        a.file_attacher.set_derivatives(derivatives_on_public_storage)
        a.save!

        a
      end

      it "#derivatives_in_correct_storage_location? is false" do
        expect(asset.derivatives_in_correct_storage_location?).to be(false)
      end
    end
  end

  # we use webmock on the Solr connection as a way to test "did update get triggered?"
  describe "changes can trigger re-index on parent work, ", indexable_callbacks: true do
    # regex because we don't care about query params after like softCommit=true or whatever.
    let(:solr_update_url_regex) { /^#{Regexp.escape(ScihistDigicoll::Env.lookup!(:solr_url) + "/update/json")}/ }

    before do
      # webmock
      stub_request(:any, solr_update_url_regex)
    end

    describe "update asset" do
      let(:asset) do
        # save our initial asset without going to solr, we're not interested in that.
        Kithe::Indexable.index_with(disable_callbacks: true) do
          create(:asset, parent: create(:work))
        end
      end

      it "re-indexes when relevant attribute changes" do
        asset.english_translation = "translation"
        asset.save!

        expect(WebMock).to have_requested(:post, solr_update_url_regex)
      end

      it "does not re-index when relevant attributes did not change" do
        asset.title = "new one"
        asset.save!
        expect(WebMock).not_to have_requested(:post, solr_update_url_regex)
      end
    end

    describe "create new child asset" do
      let(:parent) do
        Kithe::Indexable.index_with(disable_callbacks: true) do
          create(:work)
        end
      end

      it "does not re-index parent without relevant attributes in child" do
        Asset.create!(title: "asset", parent: parent)
        expect(WebMock).not_to have_requested(:post, solr_update_url_regex)
      end

      it "re-indexes parent with relevant attributes in child" do
        Asset.create!(title: "asset", transcription: "transcription", parent: parent)
        expect(WebMock).to have_requested(:post, solr_update_url_regex)
      end
    end

    describe "destroy asset" do
      let(:asset) do
        # save our initial asset without going to solr, we're not interested in that.
        Kithe::Indexable.index_with(disable_callbacks: true) do
          create(:asset, parent: create(:work))
        end
      end

      it "when no relevant attributes does not re-index " do
        asset.destroy!
        expect(WebMock).not_to have_requested(:post, solr_update_url_regex)
      end

      describe "when asset has relevant attributes" do
        let(:asset) do
          # save our initial asset without going to solr, we're not interested in that.
          Kithe::Indexable.index_with(disable_callbacks: true) do
            create(:asset, parent: create(:work), english_translation: "some translation")
          end
        end

        it "re-indexes" do
          asset.destroy!
          expect(WebMock).to have_requested(:post, solr_update_url_regex)
        end
      end
    end

    describe "existing asset with indexed attributes" do
      let(:asset) do
        # save our initial asset without going to solr, we're not interested in that.
        Kithe::Indexable.index_with(disable_callbacks: true) do
          create(:asset, parent: create(:work), transcription: "some transcription")
        end
      end

      it "is reindexed on published status change" do
        asset.update!(published: !asset.published)
        expect(WebMock).to have_requested(:post, solr_update_url_regex)
      end
    end
  end


  describe "logging" do
    let(:asset) { create(:asset_with_faked_file, parent: create(:work)).tap(&:friendlier_id) }
    let(:info_logged) { [] }
    before do
      allow(Rails.logger).to receive(:info) do |msg|
        info_logged << msg
      end
    end

    it "logs after destroy" do
      asset.destroy!
      expect(info_logged).to include /Asset Destroyed: pk=#{asset.id} friendlier_id=#{asset.friendlier_id} original_filename=#{asset.original_filename} created_at=#{asset.created_at.iso8601}/
    end
  end

  describe "#file_category" do
    describe "image" do
      let(:asset) { create(:asset_with_faked_file) }
      it "correct" do
        expect(asset.file_category).to eq("image")
      end
    end

    describe "pdf" do
      let(:asset) { create(:asset_with_faked_file, :pdf) }
      it "correct" do
        expect(asset.file_category).to eq("pdf")
      end
    end

    describe "mp3" do
      let(:asset) { create(:asset_with_faked_file, :mp3) }
      it "correct" do
        expect(asset.file_category).to eq("audio")
      end
    end

    describe "video", queue_adapter: :test do
      let(:asset) { create(:asset_with_faked_file, :video) }
      it "correct" do
        expect(asset.file_category).to eq("video")
      end

      it "enqueues job to create HLS"  do
        expect {
          build(:asset, file: File.open(Rails.root + "spec/test_support/video/sample_video.mp4")).tap do |asset|
            # We want to promote inline, but still have derivatives in ActiveJob, so we
            # can test that HLS job was enqueued.
            asset.file_attacher.set_promotion_directives(promote: :inline)
            asset.save!
          end
        }.to have_enqueued_job(CreateHlsVideoJob)
      end
    end

    describe "unknown content-type" do
      let(:asset) { create(:asset) }
      it "can still route with 'unk'" do
        expect(asset.file_category).to eq("unk")
      end
    end
  end

  describe "white edge detection", queue_adapter: :inline do
    let(:asset) {
      create(:asset, file: File.open(Rails.root + "spec/test_support/images/white_border_scan_80px.jpg"))
    }

    it "detects" do
      expect(asset.file_metadata[AssetUploader::WHITE_EDGE_DETECT_KEY]).to be true
    end
  end

  describe "vtt_transcript derivative attachments" do
    let(:sample_webvtt) do
      <<~EOS
        WEBVTT

        00:00.000 --> 00:01.500
        Hello, welcome to the podcast.
      EOS
    end
    let(:asset) { create(:asset_with_faked_file, :video) }

    it "asr_webvtt added with metadata and retrived" do
      # using a kithe feature with `add_metadata`
      asset.file_attacher.add_persisted_derivatives(
        {Asset::ASR_WEBVTT_DERIVATIVE_KEY => StringIO.new(sample_webvtt)},
        add_metadata:  { Asset::ASR_WEBVTT_DERIVATIVE_KEY => { "foo" => "bar"}}
      )

      expect(asset.asr_webvtt_str).to eq sample_webvtt

      expect(DateTime.parse(asset.file_derivatives[Asset::ASR_WEBVTT_DERIVATIVE_KEY].metadata["created_at"])).to be <= DateTime.now
      expect(asset.file_derivatives[Asset::ASR_WEBVTT_DERIVATIVE_KEY].metadata["foo"]).to eq "bar"
    end

    it "corrected_webvtt added with metadata and retrived" do
      # using a kithe feature with `add_metadata`
      asset.file_attacher.add_persisted_derivatives(
        {Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY => StringIO.new(sample_webvtt)},
        add_metadata:  { Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY => { "foo" => "bar"}}
      )

      expect(asset.corrected_webvtt_str).to eq sample_webvtt

      expect(DateTime.parse(asset.file_derivatives[Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY].metadata["created_at"])).to be <= DateTime.now
      expect(asset.file_derivatives[Asset::CORRECTED_WEBVTT_DERIVATIVE_KEY].metadata["foo"]).to eq "bar"
    end
  end
end
