require 'rails_helper'

describe ThumbDisplay do
  let(:placeholder_selector) { "img[src*=placeholder]" }
  let(:instance) { ThumbDisplay.new(argument) }
  let(:rendered) { Nokogiri::HTML.fragment(instance.display) }

  describe "with nil argument" do
    let(:argument) { nil }
    it "renders placeholder" do
      expect(rendered).to have_selector(placeholder_selector)
    end
  end

  describe "asset missing derivatives" do
    let(:argument) do
      create(:asset).tap do |asset|
        allow(asset).to receive(:content_type).and_return("image/jpeg")
      end
    end
    it "renders placeholder" do
      expect(rendered).to have_selector(placeholder_selector)
    end
  end

  describe "non-handlable type" do
    let(:argument) do
      create(:asset).tap do |asset|
        allow(asset).to receive(:content_type).and_return("audio/mpeg")
      end
    end
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
    let(:instance) { ThumbDisplay.new(argument, placeholder_img_url: specified_img_url) }

    let(:specified_img_url) { "http://example.org/image.jpg" }

    it "is used for placeholder" do
      expect(rendered).to have_selector("img[src='#{specified_img_url}']")
    end
  end

  describe "specified thumb size" do
    let(:thumb_size) { :mini }
    let(:argument) { create(:asset, :inline_promoted_file)}
    let(:instance) { ThumbDisplay.new(argument, thumb_size: thumb_size) }

    it "renders" do
      deriv    = argument.derivative_for("thumb_#{thumb_size}")
      deriv_2x = argument.derivative_for("thumb_#{thumb_size}_2X")

      img_tag = rendered.at_css("img")

      expect(img_tag).to be_present
      expect(img_tag["src"]). to eq(deriv.url)
      expect(img_tag["srcset"]).to eq("#{deriv.url} 1x, #{deriv_2x.url} 2x")
    end
  end
end
