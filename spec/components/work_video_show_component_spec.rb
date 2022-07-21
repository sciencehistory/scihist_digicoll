require 'rails_helper'

describe WorkVideoShowComponent, type: :component do
  let(:work) { create(:video_work, :published) }
  let(:placeholder_img_src) { ActionController::Base.helpers.asset_path("placeholderbox.svg") }

  it "has video element properly set up" do
    render_inline described_class.new(work)

    video_element = page.first("video")

    expect(video_element).to be_present
    expect(video_element["poster"]).to eq work.representative.file_derivatives[:thumb_large].url

    source_element = video_element.find("source")

    expect(source_element["src"]).to eq work.representative.file_url
    expect(source_element["type"]).to eq work.representative.content_type
  end

  describe "when it is missing derivatives" do
    before do
      work.representative.remove_derivatives(*work.representative.file_derivatives.keys)
      expect(work.representative.file_derivatives).to be_empty
    end

    it "can still display page without errors" do
      render_inline described_class.new(work)
      expect(page.first("video")).to be_present
    end
  end

  describe "when we have an HLS URL" do
    # Work with an hls url that doesn't actually point anywhere, but fine,
    # we just set it to point to a non-existent thing using shrine
    # internals.
    let(:work) do
      create(:video_work, :published).tap do |work|
        work.representative.hls_playlist_file_attacher.set(
          VideoHlsUploader.uploaded_file(
            storage: "video_derivatives",
            id: "some_path/hls.m3uh"
          )
        )
        work.representative.save!
      end
    end

    it "outputs HLS url in video tag" do
      render_inline described_class.new(work)

      video_element = page.first("video")
      first_source_element = video_element.first("source")

      expect(first_source_element).to be_present
      expect(first_source_element["type"]).to eq("application/x-mpegURL")
      expect(first_source_element["src"]).to eq(work.representative.hls_playlist_file.url(public: true))
    end
  end

  describe "when representative is not visible to non-logged-in user" do
    let(:work) do
      create(:video_work, :published).tap do |work|
        work.representative.update(published: false)
      end
    end

    it "includes placeholder only" do
      render_inline described_class.new(work)

      expect(page).not_to have_css("video")
      expect(page).to have_css("img[src='#{placeholder_img_src}']")
    end
  end
end

