require 'rails_helper'

describe OralHistory::ParagraphTranscriptComponent, type: :component do
  let(:paragraph_transcript_component) { described_class.new(paragraph_objs) }

  describe "with real data" do
    # We could make tests go faster by loading pre-formed Paragraph json instead of
    # transforming it live? Is that still safe enough?
    let(:extracted_pdf_text) { OralHistory::ExtractPdfText.new(pdf_file_path: oh_pdf_path).extract_pdf_text }
    let(:splitter) { OralHistory::ExtractedPdfTextParagraphSplitter.new(extracted_pdf_text: extracted_pdf_text, file_start_times: file_start_times) }

    # A good one that has <T:> timestamps and lets us test a number of things.
    let(:oh_pdf_path) { Rails.root + "spec/test_support/pdf/oh/macfarlane_1982_sequence_timestamps_example.pdf" }
    # start_times from real macfarlane, although it doesn't matter too much for these purposes as long
    # as the correct number of files
    let(:file_start_times) { { "9ccaf328-1626-470f-aed2-2a040a6e2d4b" => 0, "a8057542-4191-4bd3-a7c8-455ba958c1b6" => 9115.82 } }

    let(:paragraph_objs) { splitter.paragraphs }

    it "renders html as expected" do
      parsed = render_inline(paragraph_transcript_component)

      paragraphs = parsed.css(".ohms-transcript-container p.ohms-transcript-paragraph")
      expect(paragraphs).to all(satisfy { |el| el["id"].present? })

      first_paragraph = paragraphs.first
      expect(first_paragraph).to have_css("span.ohms-transcript-timestamp", text: "Page 1")
      expect(first_paragraph).to have_css("span.transcript-speaker", text: "GRAYSON")
      expect(first_paragraph.text).to include "So, I’m going to start the way we usually do by saying, my name is Mike Grayson"

      # Don't use same speaker name in multiple paragraphs in a row
      expect(paragraphs.collect { |p| p.css("span.transcript-speaker")&.text }.each_cons(2)).to all(
        satisfy { |a, b| a != b || a.blank? }
      )

      # Use timecode links where we got em, we only have three non-sequential in this sample
      expect( paragraphs.collect { |p| p.at_css("a.ohms-transcript-timestamp")&.text }.compact ).to eq [
        "02:30:00", "02:36:55", "02:41:55"
      ]

      expect(paragraphs.collect { |p| p.at_css("a.ohms-transcript-timestamp").try(:[], 'data-ohms-timestamp-s') }.compact).to eq [
        "9000.000", "9415.820", "9715.820"
      ]
    end
  end

  describe "unsafe html in text" do
    let(:paragraph_objs) do
      [
        OralHistoryContent::Paragraph.new(
          speaker_name: "JOHNSON",
          text: "It’s a <i>blue</i> <script>apple</script> tree!"
        ),
        OralHistoryContent::Paragraph.new(
          speaker_name: "HERNANDEZ",
          text: "This content has some <b>bold</b> and <T: 5 min> <i>italics</i>"
        ),
        OralHistoryContent::Paragraph.new(
          speaker_name: "JOHNSON",
          text: "Here is a <PAGE-BREAK next='2'></PAGE-BREAK> one with page break"
        )
      ]
    end

    it "scrubs output" do
      parsed = render_inline(paragraph_transcript_component)

      paragraphs = parsed.css(".ohms-transcript-container p.ohms-transcript-paragraph")

      expect(paragraphs.length).to eq 3

      # escape everything
      expect(paragraphs[0].inner_html).to include "It’s a &lt;i&gt;blue&lt;/i&gt; &lt;script&gt;apple&lt;/script&gt; tree!"
      expect(paragraphs[1].inner_html).to include "This content has some &lt;b&gt;bold&lt;/b&gt; and &lt;T: 5 min&gt; &lt;i&gt;italics&lt;/i&gt"
      expect(paragraphs[2].inner_html).to include "Here is a &lt;PAGE-BREAK next='2'&gt;&lt;/PAGE-BREAK&gt; one with page break"
    end
  end

  describe "with base_link" do
    let(:paragraph_transcript_component) { described_class.new(paragraph_objs, base_link: "/foo/bar") }
    let(:paragraph_objs) do
      [
        OralHistoryContent::Paragraph.new(
          speaker_name: "JOHNSON",
          text: "One",
          included_timestamps: [120]
        ),
        OralHistoryContent::Paragraph.new(
          speaker_name: "HERNANDEZ",
          text: "Two",
          included_timestamps: [132]
        )
      ]
    end

    it "includes in link" do
      parsed = render_inline(paragraph_transcript_component)

      expect(
        parsed.at_css("a.ohms-transcript-timestamp[href^='/foo/bar#t=']")
      ).to be_present
    end
  end
end
