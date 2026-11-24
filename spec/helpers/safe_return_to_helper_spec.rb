require "rails_helper"

describe SafeReturnToHelper, type: :helper do
  it "allows local paths, including query and #fragment" do
    expect(helper.safe_return_to("/works/abc")).to eq "/works/abc"
    expect(helper.safe_return_to("/works/abc?x=1#p=12&th=some%20words")).to eq "/works/abc?x=1#p=12&th=some%20words"
  end

  it "rejects nil, blank, and non-strings" do
    expect(helper.safe_return_to(nil)).to be_nil
    expect(helper.safe_return_to("")).to be_nil
    expect(helper.safe_return_to(["/works/abc"])).to be_nil
  end

  it "rejects off-site URLs" do
    expect(helper.safe_return_to("http://evil.example.com/")).to be_nil
    expect(helper.safe_return_to("//evil.example.com/")).to be_nil
    expect(helper.safe_return_to("/\\evil.example.com/")).to be_nil
    expect(helper.safe_return_to("works/abc")).to be_nil
  end

  it "rejects control characters" do
    expect(helper.safe_return_to("/works/abc\r\nX-Evil: 1")).to be_nil
  end
end
