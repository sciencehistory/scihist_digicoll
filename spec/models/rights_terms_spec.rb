require 'rails_helper'

describe RightsTerms do

  it "#all_ids" do
    expect(described_class.all_ids).to be_present
  end

  it "#collection_for_select" do
    expect(described_class.collection_for_select).to be_present
    expect(
      described_class.collection_for_select.all? {|v| v.is_a?(Array) && v.length == 2}
    ).to be true
  end

  describe "for standard id" do
    let(:id) { "http://rightsstatements.org/vocab/InC/1.0/" }

    it "can look up label" do
      expect(described_class.label_for(id)).to be_present
    end

    it "can look up category" do
      expect(described_class.category_for(id)).to be_present
    end

    it "can look up short_label_html_for" do
      expect(described_class.short_label_html_for(id)).to be_present
    end

    it "can look up short_label_inline" do
      expect(described_class.short_label_inline_for(id)).to be_present
      expect(described_class.short_label_inline_for(id)).not_to include("br")
    end
  end
end
