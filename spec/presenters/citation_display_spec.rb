require 'rails_helper'

describe CitationDisplay do
  let(:work) { FactoryBot.create(:work, :with_complete_metadata,
    date_of_work: [
      Work::DateOfWork.new(start: "2000-01-01", start_qualifier: "circa"),
      Work::DateOfWork.new(start: "2019-10-10")
    ],
    source: "The Horse's Mouth",
    creator: [
      {category: "author", value: "The Author"}
    ]
  )}

  let(:presenter) { described_class.new(work) }
  let(:rendered) { presenter.display }

  it "should raise unless a Work is passed in" do
    expect{described_class.new(FactoryBot.create(:asset))}.to raise_error(ArgumentError)
  end

  it "displays" do
    expect(rendered).to be_a ActiveSupport::SafeBuffer
    expect(rendered).to eq "The Author. “Test Title.” Audiocassettes, celluloid, dye. <i>The Horse's Mouth</i>, circa 2000–2019. Science History Institute. Philadelphia. https://localhost/works/#{work.friendlier_id}."
  end

end