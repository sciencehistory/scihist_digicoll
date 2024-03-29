require 'rails_helper'

describe OralHistoryEmailAssetItemComponent, type: :component do
  let!(:doc) { render_inline(described_class.new(asset)) }

  describe "mp3 asset" do
    let(:asset) do
      build(:asset_with_faked_file, :mp3,
        published: false,
        oh_available_by_request: true,
        faked_filename: "smith_h_1_1.mp3",
        faked_size: 21.2.megabytes,
        faked_derivatives: {} )
    end

    it "outputs mp3 link" do
      expect(page).to have_css("a", text: /.mp3 - listen/)
    end

    it "outputs mp3 download link" do
      expect(page).to have_css("a", text: "MP3 - 21.2 MB")
    end
  end

  describe "FLAC asset with M4A deriv" do
    let(:asset) do
      build(:asset_with_faked_file, :flac,
        published: false,
        oh_available_by_request: true,
        faked_filename: "smith_h_1_1.flac",
        faked_size: 210.2.megabytes,
        faked_derivatives: {
          m4a: create(:stored_uploaded_file,
              file: File.open((Rails.root + "spec/test_support/audio/5-seconds-of-silence.m4a").to_s),
              size: 12.4.megabytes,
              content_type: "audio/mp4")
        } )
    end

    it "outputs m4a link not flac" do
      expect(page).to have_css("a", text: /.m4a - listen/)
      expect(page).not_to have_css("a", text: /.flac - listen/)
    end

    it "outputs m4a download link" do
      expect(page).to have_css("a", text: "M4A - 12.4 MB")
    end

    it "outputs FLAC download link" do
      expect(page).to have_css("a", text: "FLAC - 210 MB")
    end
  end
end
