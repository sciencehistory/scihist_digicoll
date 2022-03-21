require 'rails_helper'

describe WorkVideoShowComponent, type: :component do
  let(:work) { create(:video_work, :published) }

  it "has video element properly set up" do
    render_inline described_class.new(work)

    video_element = page.first("video")

    expect(video_element).to be_present
    expect(video_element["poster"]).to eq work.representative.file_derivatives["thumb_large"].url

    source_element = video_element.find("source")

    expect(source_element["src"]).to eq work.representative.file_url
    expect(source_element["type"]).to eq work.representative.content_type
  end

  describe "when it is missing derivatives" do
    let(:work) do
      create(:video_work, :published).tap do |work|
        work.representative.remove_derivatives( *work.representative.file_derivatives.keys )
      end
    end

    it "can still display page without errors" do
      expect(work.representative.file_derivatives).to be_empty

      render_inline described_class.new(work)
      expect(page.first("video")).to be_present
    end
  end
end

