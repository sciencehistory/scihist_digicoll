require 'rails_helper'

describe BarChartComponent, type: :component do
  let(:series) { ["Created", "Published"] }
  let(:groups) do
    {
      "July 2026"   => [210, 220],
      "August 2026" => [240, 1275],
      "Sep 2026"    => [nil, 280]
    }
  end
  let(:component) { described_class.new(caption: "Items per month", series: series, groups: groups) }
  let(:page) { render_inline(component) }

  it "renders a figure with caption and a list item per group" do
    expect(page.at_css("figure.bar-chart > figcaption").text).to eq "Items per month"
    expect(page.css(".bar-chart__group-label").map(&:text)).to eq ["July 2026", "August 2026", "Sep 2026"]
  end

  it "renders label and formatted value text for every bar" do
    first_group = page.css(".bar-chart__group").first
    expect(first_group.css(".bar-chart__bar-label").map(&:text)).to eq series
    expect(first_group.css(".bar-chart__bar-value").map(&:text)).to eq ["210", "220"]

    expect(page.css(".bar-chart__bar-value").map(&:text)).to include("1,275", "–")
  end

  it "sets value and max custom properties for CSS" do
    expect(page.at_css("figure")["style"]).to include("--bar-chart-max: 1275.0")
    expect(page.at_css(".bar-chart__bar")["style"]).to include("--bar-chart-value: 210.0")
  end

  it "gives nil values no value property, so no bar" do
    nil_bar = page.css(".bar-chart__group").last.css(".bar-chart__bar").first
    expect(nil_bar["style"].to_s).not_to include("--bar-chart-value")
  end

  it "accepts explicit max" do
    page = render_inline(described_class.new(series: series, groups: groups, max: 2000))
    expect(page.at_css("figure")["style"]).to include("--bar-chart-max: 2000.0")
  end

  it "raises on wrong number of values" do
    expect {
      described_class.new(series: series, groups: { "July 2026" => [1] })
    }.to raise_error(ArgumentError, /July 2026/)
  end
end
