require 'rails_helper'

describe AttributeTable::ListValuesDisplay do
  let(:values) { ["one", "one & two", "'three' <>>> four >>>"] }

  let(:displayer) { AttributeTable::ListValuesDisplay.new(values) }
  let(:rendered) { Nokogiri::HTML.fragment(displayer.display)}

  it "creates a <ul>" do
    expect(rendered).to have_selector("ul")

    ul = rendered.at_xpath("ul")

    values.each do |v|
      # capybara handles escaping/unescaping, this can't pass unless it's escaped properly:
      expect(ul).to have_selector("li", class: "attribute", text: v)
    end

  end

  describe "link_to_facet" do
    let(:displayer) { AttributeTable::ListValuesDisplay.new(values, link_to_facet: :subject_facet) }

    it "creates links to facet" do
      values.each do |v|
        expect(rendered).to have_link(v, href: helper.search_on_facet_path(:subject_facet, v))
      end
    end
  end
end
