require 'rails_helper'

describe AttributeTable::RowComponent, type: :component do
  let(:values) { ["one", "one & two", "'three' <>>> four >>>"] }

  let(:displayer) { AttributeTable::RowComponent.new(:place_of_publication, values: values) }
  let(:rendered) {
    render_inline(displayer)
    # workaorund for ViewComponent/Nokogiri HTML5 issue
    # https://github.com/ViewComponent/view_component/issues/2422#issuecomment-3168271669
    Nokogiri::HTML5.fragment(@rendered_content, context: "template")
  }

  it "renders a row" do
    tr = rendered.at_css("tr")
    expect(tr).to be_present

    expect(tr).to have_selector("th", text: "Place of publication")

    td = tr.at_xpath("td")
    expect(td).to be_present
  end

  describe "alpha_sort" do
    let(:values) { ["b", "e", "a", "c", "d"]}
    let(:displayer) { AttributeTable::RowComponent.new(:place_of_publication, values: values, alpha_sort: true) }
    it 'sorts' do
      ordered_values = rendered.css("li.attribute").collect(&:text)
      expect(ordered_values).to eq ["a", "b", "c", "d", "e"]
    end
  end

  describe "with empty array input" do
    let(:values) { [] }
    it "renders empty string" do
      expect(rendered.to_html).to eq ""
    end
  end

  describe "with nil input" do
    let(:values) { nil }
    it "renders empty string" do
      expect(rendered.to_html).to eq ""
    end
  end

  describe "with included empty string and nil" do
    let(:values) { ["one", nil, "", "two"] }
    it "skips em" do
      tr = rendered.at_css("tr")
      expect(tr).to be_present

      td = tr.at_xpath("td")

      expect(td).to have_selector("li", count: 2)
    end
  end
end
