require 'rails_helper'

describe ThumbComponent, type: :component do
  let(:placeholder_selector) { "img[src*=placeholder]" }
  let(:instance) { ThumbComponent.new(argument) }
  let(:rendered) { render_inline(instance) }

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

  describe "audio type" do
    let(:argument) do
      build(:asset).tap do |asset|
        allow(asset).to receive(:content_type).and_return("audio/mpeg")
      end
    end
    it "renders audio file svg" do
      expect(rendered).to have_selector("svg.fa-custom-svg")
    end
  end

  describe "non-handlable type" do
    let(:argument) do
      build(:asset).tap do |asset|
        allow(asset).to receive(:content_type).and_return("video/mpeg")
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

  describe "with alt_text" do
    let(:alt_text) { "This is alt text" }
    let(:argument) { build(:asset_with_faked_file, alt_text: alt_text) }

    it "renders alt attribute from model alt_text" do
      img_tag = rendered.at_css("img")
      expect(img_tag).to be_present
      expect(img_tag["alt"]).to eq(alt_text)
    end
  end

  describe "specified placeholder image" do
    let(:argument) { build(:asset) }
    let(:instance) { ThumbComponent.new(argument, placeholder_img_url: specified_img_url) }

    let(:specified_img_url) { "http://example.org/image.jpg" }

    it "is used for placeholder" do
      expect(rendered).to have_selector("img[src='#{specified_img_url}']")
    end
  end

  describe "specified thumb size" do
    let(:thumb_size) { :mini }
    let(:argument) { build(:asset_with_faked_file)}
    let(:instance) { ThumbComponent.new(argument, thumb_size: thumb_size) }
    let(:expected_aspect_ratio) { (argument.height.to_f / argument.width.to_f * 100.0).truncate(1) }

    it "renders" do
      deriv    = argument.file_derivatives[:"thumb_#{thumb_size}"]
      deriv_2x = argument.file_derivatives[:"thumb_#{thumb_size}_2X"]

      img_tag = rendered.at_css("img")

      expect(img_tag).to be_present
      expect(img_tag["src"]).to eq(deriv.url)
      expect(img_tag["srcset"]).to eq("#{deriv.url} 1x, #{deriv_2x.url} 2x")
      expect(img_tag["style"]).to eq "aspect-ratio: #{argument.width} / #{argument.height}"
    end

    describe "fetchpriority" do
      let(:instance) { ThumbComponent.new(argument, thumb_size: thumb_size, fetchpriority: "high") }

      it "is included as argument" do
        img_tag = rendered.at_css("img")
        expect(img_tag[:fetchpriority]).to eq "high"
      end
    end

    describe "with no aspect ratio available" do
      let(:argument) do
        build(:asset_with_faked_file).tap do |asset|
          thumb = asset.file("thumb_#{thumb_size}")
          thumb.metadata.delete("height")
          thumb.metadata.delete("width")
          asset.save!
        end
      end

      it "renders without aspectratio-container" do
        wrapper = rendered.at_css(".img-aspectratio-container")
        expect(wrapper).not_to be_present

        img_tag = rendered.at_css("img")
        expect(img_tag["src"]).to be_present
      end
    end

    describe "lazy load with native lazyloading" do
      let(:thumb_size) { :mini }
      let(:argument) { build(:asset_with_faked_file)}
      let(:instance) { ThumbComponent.new(argument, thumb_size: thumb_size, lazy: true) }
      let(:expected_aspect_ratio) { (argument.height.to_f / argument.width.to_f * 100.0).truncate(1) }


      it "renders with proper src and loading=lazy" do
        deriv    = argument.file_derivatives[:"thumb_#{thumb_size}"]
        deriv_2x = argument.file_derivatives[:"thumb_#{thumb_size}_2X"]

        img_tag = rendered.at_css("img")

        expect(img_tag).to be_present
        expect(img_tag["src"]).to eq deriv.url
        expect(img_tag["srcset"]).to eq("#{deriv.url} 1x, #{deriv_2x.url} 2x")

        expect(img_tag["loading"]).to eq "lazy"
        expect(img_tag["decoding"]).to eq "async"

        # old lazysizes.js
        expect(img_tag["data-src"]).not_to eq(deriv.url)
        expect(img_tag["data-srcset"]).not_to eq("#{deriv.url} 1x, #{deriv_2x.url} 2x")
      end
    end

    describe "Provide alternate alt text to display" do
      let(:thumb_size) { :standard }
      let(:alt_text_override) {"Override regular alt text with this string."}
      let(:argument) {  build(:asset_with_faked_file, alt_text: "this should get overridden") }
      let(:instance) { ThumbComponent.new(argument, thumb_size: thumb_size, alt_text_override: alt_text_override) }
      it "overrides regular alt text on the image" do
        img_tag = rendered.at_css("img")
        expect(img_tag["alt"]).to eq(alt_text_override)
      end
    end

  end
end
