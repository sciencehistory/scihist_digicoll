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
      build(:asset).tap do |asset|
        allow(asset).to receive(:content_type).and_return("image/jpeg")
      end
    end
    it "renders placeholder" do
      expect(rendered).to have_selector(placeholder_selector)
    end
  end

  describe "non-handlable type" do
    let(:argument) do
      build(:asset).tap do |asset|
        allow(asset).to receive(:content_type).and_return("audio/mpeg")
      end
    end
    it "renders placeholder" do
      expect(rendered).to have_selector(placeholder_selector)
    end
  end

  describe "asset with 'standard' size derivatives" do
    let(:argument) { build(:asset_with_faked_file)}
    it "renders img with srcset" do
      standard_deriv    = argument.file_derivatives[:thumb_standard]
      standard_2x_deriv = argument.file_derivatives[:thumb_standard_2X]

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
    let(:argument) { build(:asset_with_faked_file)}
    let(:instance) { ThumbDisplay.new(argument, thumb_size: thumb_size) }
    let(:expected_aspect_ratio) { (argument.height.to_f / argument.width.to_f * 100.0).truncate(1) }

    it "renders" do
      deriv    = argument.file_derivatives[:"thumb_#{thumb_size}"]
      deriv_2x = argument.file_derivatives[:"thumb_#{thumb_size}_2X"]

      wrapper = rendered.at_css(".img-aspectratio-container")
      expect(wrapper).to be_present
      expect(wrapper["style"]).to eq("padding-bottom: #{expected_aspect_ratio}%;")

      img_tag = wrapper.at_css("img")

      expect(img_tag).to be_present
      expect(img_tag["src"]).to eq(deriv.url)
      expect(img_tag["srcset"]).to eq("#{deriv.url} 1x, #{deriv_2x.url} 2x")
    end

    describe "lazy load with lazysizes.js" do
      let(:thumb_size) { :mini }
      let(:argument) { build(:asset_with_faked_file)}
      let(:instance) { ThumbDisplay.new(argument, thumb_size: thumb_size, lazy: true) }
      let(:expected_aspect_ratio) { (argument.height.to_f / argument.width.to_f * 100.0).truncate(1) }


      it "renders with lazysizes class and data- attributes" do
        deriv    = argument.file_derivatives[:"thumb_#{thumb_size}"]
        deriv_2x = argument.file_derivatives[:"thumb_#{thumb_size}_2X"]

        wrapper = rendered.at_css(".img-aspectratio-container")
        expect(wrapper).to be_present
        expect(wrapper["style"]).to eq("padding-bottom: #{expected_aspect_ratio}%;")

        img_tag = wrapper.at_css("img")

        expect(img_tag).to be_present
        expect(img_tag["src"]).not_to be_present
        expect(img_tag["srcset"]).not_to be_present

        expect(img_tag["class"]).to eq "lazyload"
        expect(img_tag["data-src"]).to eq(deriv.url)
        expect(img_tag["data-srcset"]).to eq("#{deriv.url} 1x, #{deriv_2x.url} 2x")
      end
    end
  end
end
