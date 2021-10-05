require 'rails_helper'

describe AttributeTable::ListValuesComponent, type: :component do
  # So we can use route helpers in our tests....
  include Rails.application.routes.url_helpers
  include SearchHelper

  let(:values) { ["one", "one & two", "'three' <>>> four >>>"] }

  let(:displayer) { AttributeTable::ListValuesComponent.new(values) }
  let(:rendered) { render_inline displayer }

  it "creates a <ul>" do
    expect(rendered).to have_selector("ul")

    ul = rendered.at_xpath("ul")

    values.each do |v|
      # capybara handles escaping/unescaping, this can't pass unless it's escaped properly:
      expect(ul).to have_selector("li", class: "attribute", text: v)
    end

  end

  describe "link_to_facet" do
    let(:displayer) { AttributeTable::ListValuesComponent.new(values, link_to_facet: :subject_facet) }

    it "creates links to facet" do
      values.each do |v|
        expect(rendered).to have_link(v, href: search_on_facet_path(:subject_facet, v))
      end
    end
  end
end
