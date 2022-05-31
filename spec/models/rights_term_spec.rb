require 'rails_helper'

describe RightsTerm do

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

    it ".label_for" do
      expect(described_class.label_for(id)).to be_present
    end

    describe ".find" do
      let(:term) { described_class.find(id) }

      it "#category" do
        expect(term.category).to be_present
      end

      it "#short_label_html" do
        expect(term.short_label_html).to be_present
      end

      it "can construct #short_label_inline" do
        expect(term.short_label_inline).to be_present
        expect(term.short_label_inline).not_to include("br")
      end
    end
  end

  describe "for missing id null object" do
    let(:id) { "no_such_id" }
    let(:term) { RightsTerm.find(id) }

    it "has id" do
      expect(term.id).to eq id
    end

    it "has nil label" do
      expect(term.label).to be nil
    end

    it "has blank pictographs" do
      expect(term.pictographs).to eq []
    end

    it "has nil short_label_inline" do
      expect(term.short_label_inline).to be nil
    end
  end

  describe "categories" do
    it "is one of the legal ones for everything" do
      RightsTerm.all.each do |term|
        expect(term.category).to be_in(["in_copyright", "no_copyright", "other", "creative_commons"])
      end
    end
  end
end
