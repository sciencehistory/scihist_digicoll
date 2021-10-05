require 'rails_helper'

describe ExternalLinkComponent, type: :component do
  let(:url) { "https://example.com/foo/bar" }
  let(:rendered) { render_inline(ExternalLinkComponent.new(url)).to_html }

  it "formats as link" do
    expect(rendered).to eq  "<a target=\"_blank\" href=\"https://example.com/foo/bar\"><i class=\"fa fa-external-link\"></i>\u00A0example.com/…</a>"
  end
end
