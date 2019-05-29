require 'rails_helper'

describe DescriptionDisplayFormatter, type: :model do
  url = "http://www.randomurl.org"
  untouched = "<p><cite>These</cite><i>tags</i><b>are</b><a href=\"#{url}\">OK</a>.</p>"

  describe "no truncation" do
    {
      "Adds paragraph tags" => "<p>Adds paragraph tags</p>",
      "escapes things > for html" => "<p>escapes things &gt; for html</p>",
      "Adds \n returns" => "<p>Adds \n<br /> returns</p>",
      "Adds \n\n returns" => "<p>Adds </p>\n\n<p> returns</p>",
      "Adds\n\nreturns\nproperly" => "<p>Adds</p>\n\n<p>returns\n<br />properly</p>",
      "Strips <goat>unwanted tags </goat>" => "<p>Strips unwanted tags </p>",
      "Adds links to http://www.randomurl.org" => "<p>Adds links to <a href=\"http://www.randomurl.org\"><i class=\"fa fa-external-link\" aria-hidden=\"true\"></i>&nbsp;http://www.randomurl.org</a></p>",
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
    truncated_output = DescriptionDisplayFormatter.
      new(long_html_string, truncate:true).format

    it "correctly truncates a long html string" do
      expect(truncated_output.length).to be < long_html_string.length
    end
  end
end
