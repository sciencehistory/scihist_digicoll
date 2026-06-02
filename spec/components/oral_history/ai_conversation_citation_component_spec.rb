require 'rails_helper'

describe OralHistory::AiConversationCitationComponent, type: :component do
  let(:work) {
    build(:oral_history_work,
      :with_extracted_paragraph_container,
      friendlier_id: "12ab12ab12",
      date_of_work: { start: "2012" },
      creator: [{ category: "interviewee", value: "Hanford, William E., 1908-1996"},
                { category: "interviewer", value: "Bohning, James J."}]
    )
  }

  let(:oral_history_content) { work.oral_history_content }

  let(:available_by_request_mode) { nil }
  before do
    oral_history_content.available_by_request_mode = available_by_request_mode if available_by_request_mode
  end

  let(:oral_history_chunk) { build(:oral_history_chunk, oral_history_content: oral_history_content) }

  let(:citation_item) do
    OralHistory::AiConversationDisplayComponent::CitationItem.new(
      chunk: oral_history_chunk,
      response_hash: {
        "page_number" => "4",
        "paragraph_start" => oral_history_chunk.start_paragraph_number,
        "paragraph_end" => oral_history_chunk.start_paragraph_number,
        "quote" => "This is a long enough quote that it will trigger only showing first 55 chars then rest behind javascript disclosure link"
      }
    )
  end

  let(:component) { described_class.new(citation_item) }

  let!(:rendered) { render_inline component }

  it "renders citation with page number and timecode if present" do
    expect(page). to have_text %r{Hanford, 2012,\s+p\. 4\s+near \d\d:\d\d:\d\d}
  end

  it "renders first part of quote" do
    within(".citation-quote-truncated") do
      expect(page).to have_text /This is a long enough.*…/
      expect(page).to have_selector("*[data-scihist-citation-quote-show=true]", text: "Read more")
    end
  end

  it "renders link to paragraph" do
    expect(component.link_to_source).to eq work_path(citation_item.work.friendlier_id, anchor: "p=#{citation_item.paragraph_start}&th=This is a long enough quote")
  end

  describe "automatic requestable" do
    let(:available_by_request_mode) { "automatic" }

    it "generates link to PDF with page number" do
      expect(component.link_to_source).to eq view_transcript_pdf_path(work, anchor_page: (work.oral_history_content.extracted_pdf_paragraphs.logical_page_number_offset + 4).to_s)
    end
  end
end
