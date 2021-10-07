require 'rails_helper'

describe CitationDisplay do
  let(:parent_work) { create(:public_work, title: "Parent Work" )}
  let(:expected_url_base)  { ScihistDigicoll::Env.lookup!(:app_url_base) }

  let(:work) { FactoryBot.create(:work, :with_complete_metadata,
    parent: parent_work,
    date_of_work: [
      Work::DateOfWork.new(start: "2000-01-01", start_qualifier: "circa"),
      Work::DateOfWork.new(start: "2019-10-10")
    ],
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
    expect(rendered).to eq "The Author. “Test Title.” Audiocassettes, celluloid, dye. <i>Parent Work</i>, circa 2000–2019. Science History Institute. Philadelphia. #{expected_url_base}/works/#{work.friendlier_id}."
  end

end
