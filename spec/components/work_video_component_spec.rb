require 'rails_helper'

describe WorkVideoComponent, type: :component do
  let(:work) { create(:video_work, :published) }

  before do
    render_inline described_class.new(work)
  end


  it "has video element properly set up" do
    video_element = page.first("video")

    expect(video_element).to be_present
    expect(video_element["poster"]).to eq work.representative.file_derivatives["thumb_large"].url

    source_element = video_element.find("source")

    expect(source_element["src"]).to eq work.representative.file_url
    expect(source_element["type"]).to eq work.representative.content_type
  end
end

