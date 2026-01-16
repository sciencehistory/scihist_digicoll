require 'rails_helper'

describe "work factory" do
  describe "published work" do
    let(:work) { build(:work, :published) }

    it "is valid" do
      expect(work).to be_valid
    end

    it "is published" do
      expect(work).to be_published
    end

    it "creates with representative" do
      expect(work.representative).to be_present
    end
  end

  describe "oral history work" do
    describe "published oral history work" do
      let(:work) { build(:oral_history_work, :published) }

      it "is genre oral history" do
        expect(work.genre).to eq ["Oral histories"]
      end

      it "is valid" do
        expect(work).to be_valid
      end

      it "is published" do
        expect(work).to be_published
      end

      it "has representative" do
        expect(work.representative).to be_present
      end
    end

    describe "combined_derivative" do
      let(:work) { build(:oral_history_work, :combined_derivative)}

      it "is good" do
        combined = CombinedAudioDerivatives.new(work)
        expect(combined.derivatives_up_to_date?).to be true
        expect(combined.m4a_audio_download_url).to be_present

        start_times = work.oral_history_content.combined_audio_component_metadata['start_times']
        expect(start_times).to be_present

        expect(start_times.count).to eq work.members.find_all {|m| m.content_type.start_with?("audio/")}.count
      end
    end
  end

  describe "video work" do
    describe "published video work" do
      let(:work) { build(:video_work, :published) }

      it "is valid" do
        expect(work).to be_valid
      end

      it "is published" do
        expect(work).to be_published
      end

      it "has video representative" do
        expect(work.representative).to be_present
        expect(work.representative.content_type).to eq "video/mpeg"
      end

      it "has thumbnail derivative in video representative" do
        expect(work.representative.file_derivatives.keys).to include(:thumb_large, :thumb_standard, :thumb_mini)
      end

      it "has the correct format" do
        expect(work.format).to eq(["moving_image"])
      end

      it "has an attached video with the proper mime type" do
        expect(work.representative.file_data['storage']).to eq("store")
        expect(work.representative.file_data['metadata']['mime_type']).to eq("video/mpeg")
      end
    end

    describe "published video work with a poster frame asset" do
      let(:work) { build(:video_work, :published, :with_poster_frame) }

      it "is valid" do
        expect(work).to be_valid
      end

      it "is published" do
        expect(work).to be_published
      end

      it "has video representative" do
        expect(work.representative).to be_present
        expect(work.representative.content_type).to eq "image/jpeg"
      end

      it "has thumbnail derivative in video representative" do
        expect(work.representative.file_derivatives.keys).to include(:thumb_large, :thumb_standard, :thumb_mini)
      end

      it "has the correct format" do
        expect(work.format).to eq(["moving_image"])
      end

      it "has an attached video with the proper mime type" do
        expect(work.representative.file_data['storage']).to eq("store")
        expect(work.representative.file_data['metadata']['mime_type']).to eq("image/jpeg")
      end
    end

  end


end
