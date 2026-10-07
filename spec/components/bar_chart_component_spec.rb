require 'rails_helper'

describe BarChartComponent, type: :component do
  let(:groups) do
    {
      "July 2026" => {
        "Created"   => { total: 210, current: 12 },
        "Published" => { total: 220, current: 8 }
      },
      "August 2026" => {
        "Created"   => { total: 240, current: 30 },
        "Published" => { total: 1275, current: 55 }
      },
      "Sep 2026" => {
        "Published" => { total: 280, current: nil }
      }
    }
  end
  let(:component) { described_class.new(caption: "Items per month", groups: groups) }
  let(:page) { render_inline(component) }

  it "renders a figure with caption and a list item per group" do
    expect(page.at_css("figure.bar-chart > figcaption").text).to eq "Items per month"
    expect(page.css(".bar-chart__group-label").map(&:text)).to eq ["July 2026", "August 2026", "Sep 2026"]
  end

  it "renders series labels in order of first appearance, in every group" do
    page.css(".bar-chart__group").each do |group|
      expect(group.css(".bar-chart__bar-label").map(&:text)).to eq ["Created", "Published"]
    end
  end

  it "renders total and current, with screen-reader labels and tooltips" do
    bar = page.css(".bar-chart__group").first.at_css(".bar-chart__bar")

    total = bar.at_css(".bar-chart__bar-total")
    expect(total.text).to eq "Total: 210"
    expect(total.at_css(".visually-hidden").text).to eq "Total: "
    expect(total["data-bs-toggle"]).to eq "tooltip"
    expect(total["title"]).to eq "Total"

    current = bar.at_css(".bar-chart__bar-current")
    expect(current.text).to eq "Current: 12"
    expect(current.at_css(".visually-hidden").text).to eq "Current: "
    expect(current["data-bs-toggle"]).to eq "tooltip"
    expect(current["title"]).to eq "Current"
  end

  it "formats numbers, and shows en dash for missing data" do
    expect(page.css(".bar-chart__bar-total").map(&:text)).to include("Total: 1,275")
    sep = page.css(".bar-chart__group").last
    expect(sep.css(".bar-chart__bar-total").map(&:text)).to eq ["Total: –", "Total: 280"]
    expect(sep.css(".bar-chart__bar-current").map(&:text)).to eq ["Current: –", "Current: –"]
  end

  it "sets total and max custom properties for CSS" do
    expect(page.at_css("figure")["style"]).to include("--bar-chart-max: 1275.0")
    expect(page.at_css(".bar-chart__bar")["style"]).to include("--bar-chart-value: 210.0")
  end

  it "gives missing totals no value property, so no bar" do
    missing_bar = page.css(".bar-chart__group").last.css(".bar-chart__bar").first
    expect(missing_bar["style"].to_s).not_to include("--bar-chart-value")
  end

  it "accepts explicit max" do
    page = render_inline(described_class.new(groups: groups, max: 2000))
    expect(page.at_css("figure")["style"]).to include("--bar-chart-max: 2000.0")
  end

  it "raises on unrecognized cell keys" do
    expect {
      described_class.new(groups: { "July 2026" => { "Created" => { total: 1, curent: 2 } } })
    }.to raise_error(ArgumentError, /curent/)
  end
end
