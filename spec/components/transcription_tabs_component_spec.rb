require 'rails_helper'

describe TranscriptionTabsComponent, type: :component do
  let(:feature_flag) { true }
  let(:members) do
    [
      create(:asset, handwriting_transcription: "First page\nof handwriting", transcription: "by a person"),
      create(:asset, handwriting_transcription: "Second page of handwriting")
    ]
  end
  let(:work) { create(:public_work, members: members) }

  before do
    allow(ScihistDigicoll::Env).to receive(:lookup).and_call_original
    allow(ScihistDigicoll::Env).to receive(:lookup).with(:gemini_htr_transcripts_feature_flag).and_return(feature_flag)
  end

  def render_tabs
    render_inline(described_class.new(work: work, members: work.members.order(:position).to_a)) { "description content" }
  end

  it "shows an AI Transcription tab next to the Transcription tab, with a warning and each page's text" do
    render_tabs

    expect(page).to have_link("Transcription", exact: true, href: "#transcription")
    expect(page).to have_link("AI Transcription", href: "#handwriting-transcription")

    panel = page.find("#handwriting-transcription")
    expect(panel).to have_text("generated automatically by AI")
    expect(panel).to have_css("h3.text-page-separator", count: 2)
    expect(panel).to have_css("p", text: "First page")
    expect(panel).to have_text("Second page of handwriting")
  end

  describe "with no handwriting transcriptions" do
    let(:members) { [create(:asset, transcription: "by a person")] }

    it "has no AI Transcription tab" do
      render_tabs

      expect(page).to have_link("Transcription", exact: true)
      expect(page).not_to have_link("AI Transcription")
      expect(page).not_to have_css("#handwriting-transcription")
    end
  end

  describe "with the feature flag off" do
    let(:feature_flag) { false }

    it "has no AI Transcription tab" do
      render_tabs

      expect(page).not_to have_link("AI Transcription")
      expect(page).not_to have_css("#handwriting-transcription")
    end
  end
end
