require 'rails_helper'

describe ResultThumbDisplay do
  let(:placeholder_selector) { "img[src*=placeholder]" }
  let(:rendered) { Nokogiri::HTML.fragment(ResultThumbDisplay.new(argument).display) }

  describe "with nil argument" do
    let(:argument) { nil }
    it "renders placeholder" do
      expect(rendered).to have_selector(placeholder_selector)
    end
  end

  describe "asset missing derivatives" do
    let(:argument) { create(:asset) }
    it "renders placeholder" do
      expect(rendered).to have_selector(placeholder_selector)
    end
  end

  describe "asset with 'standard' size derivatives" do
    let(:argument) { create(:asset, :inline_promoted_file)}
    it "renders img with srcset" do
      standard_deriv    = argument.derivative_for(:thumb_standard)
      standard_2x_deriv = argument.derivative_for(:thumb_standard_2X)

      img_tag = rendered.at_css("img")

      expect(img_tag).to be_present
      expect(img_tag["src"]). to eq(standard_deriv.url)
      expect(img_tag["srcset"]).to eq("#{standard_deriv.url} 1x, #{standard_2x_deriv.url} 2x")
    end
  end

  describe "specified placeholder image" do
    let(:argument) { build(:asset) }
    let(:rendered) { Nokogiri::HTML.fragment(ResultThumbDisplay.new(argument, placeholder_img_url: specified_img_url).display) }

    let(:specified_img_url) { "http://example.org/image.jpg" }

    it "is used for placeholder" do
      expect(rendered).to have_selector("img[src='#{specified_img_url}']")
    end

  end
end
