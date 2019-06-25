require 'rails_helper'

describe ExternalLinkDisplay do
  let(:url) { "https://example.com/foo/bar" }
  let(:obj) { ExternalLinkDisplay.new(url) }

  it "formats as link" do
    expect(obj.display).to eq  "<a target=\"_blank\" href=\"https://example.com/foo/bar\"><i class='fa fa-external-link'></i>&nbsp;example.com/…</a>"
  end
end
