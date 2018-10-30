require 'spec_helper'

RSpec.describe DescriptionSanitizer do

  let (:sanitized) {
    DescriptionSanitizer.new.sanitize(input)
  }

  describe "mixed input" do
    let(:input) do
      <<~EOS
        <script>evil</script>
        <p>This is a paragraph</p>
        This is a line with <b>bold</b>, <i>italic</i>, <cite>cite</cite>, and a <a href='http://example.com' onclick='foo'>link</a>.

        This is a final line
      EOS
    end
    it "sanitizes" do
      expect(sanitized).to eq(<<~EOS)
        evil
        This is a paragraph
        This is a line with <b>bold</b>, <i>italic</i>, <cite>cite</cite>, and a <a href=\"http://example.com\">link</a>.

        This is a final line
      EOS
    end
  end
end
