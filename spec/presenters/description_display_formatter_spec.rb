require 'rails_helper'

describe DescriptionDisplayFormatter, type: :model do
  url = "http://www.randomurl.org"
  untouched = "<p><cite>These</cite><i>tags</i> <b>are</b><a href=\"#{url}\">OK</a>. </p>"

  describe "no truncation" do
    {
      "Adds paragraph tags" => "<p>Adds paragraph tags</p>",
      "escapes things > for html" => "<p>escapes things &gt; for html</p>",
      "Adds \n returns" => "<p>Adds \n<br /> returns</p>",
      "Adds \n\n returns" => "<p>Adds </p>\n\n<p> returns</p>",
      "Adds\n\nreturns\nproperly" => "<p>Adds</p>\n\n<p>returns\n<br />properly</p>",
      "Strips <goat>unwanted tags </goat>" => "<p>Strips unwanted tags </p>",
      "Adds links to http://www.randomurl.org" => "<p>Adds links to <a href=\"http://www.randomurl.org\"><i class=\"fa fa-external-link\" aria-hidden=\"true\"></i>&nbsp;http://www.randomurl.org</a></p>",
      nil => "",
      "" => "",
      untouched => untouched,

    }.each do |input, output|
      it "should format '#{input}' as #{output}" do
        expect(DescriptionDisplayFormatter.new(input).format).to eq(output)
      end
    end

    it "marks html safe" do
      expect(DescriptionDisplayFormatter.new("some input").format).to be_html_safe
    end
  end

  describe "truncation" do
    long_html_string = untouched * 20
    $debugging = true
    truncated_output = DescriptionDisplayFormatter.new(long_html_string, truncate:true).format
    $debugging = false

    it "correctly truncates a long html string" do
      expect(truncated_output.length).to be < long_html_string.length
    end

    it "can truncate to explicit value" do
      truncated = DescriptionDisplayFormatter.new(long_html_string, truncate: 20).format
      expect(helpers.strip_tags(truncated).length).to be <= 20
    end

  end

  describe "#format_plain" do
    let(:html_description) { untouched }
    let(:formatted) { DescriptionDisplayFormatter.new(html_description).format_plain }

    it "is not html_safe" do
      expect(formatted).not_to be_html_safe
    end

    it "has html tags removed" do
      expect(formatted).to eq helpers.strip_tags(html_description)
    end

    describe "with very long description" do
      let(:html_description) { untouched * 100 }
      let(:formatted) { DescriptionDisplayFormatter.new(html_description, truncate: 400).format_plain }

      it "truncates" do
        expect(formatted.length).to be < 400
      end
    end
  end
end
