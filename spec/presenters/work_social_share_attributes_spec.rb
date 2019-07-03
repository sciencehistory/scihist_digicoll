require 'rails_helper'

describe WorkSocialShareAttributes do
  let(:title) { "some work" }
  let(:description) { "This is a thing" }
  let(:work) { build(:work, title: title, description: description) }
  let(:attributes) { WorkSocialShareAttributes.new(work) }

  describe "#page_title" do
    it "is correct" do
      expect(attributes.page_title).to eq "#{title} - Science History Institute Digital Collections"
    end
  end

  describe "#share_url" do
    let(:work) { create(:work) }
    it "is correct" do
      expect(attributes.share_url).to eq helper.work_url(work)
      expect(Addressable::URI.parse(attributes.share_url)).not_to be_relative
    end
  end

  describe "#share_media_url" do
    let(:work) { create(:work, representative: create(:asset, :faked_image_file))}
    let(:download_medium_derivative) { work.representative.derivative_for(:download_medium) }

    it "direct link to 'medium' download derivative of representative" do
      parsed_uri = Addressable::URI.parse attributes.share_media_url

      expect(parsed_uri).not_to be_relative
      expect(parsed_uri.path).to eq(Addressable::URI.parse(download_medium_derivative.url(public: true)).path)
    end

    it "has share_media_height" do
      expect(attributes.share_media_height).to be_present
      expect(attributes.share_media_height).to eq download_medium_derivative.height
    end

    it "has share_media_width" do
      expect(attributes.share_media_width).to be_present
      expect(attributes.share_media_width).to eq download_medium_derivative.width
    end

    describe "with no representative" do
      let(:work) { build(:work) }

      it "has nil values" do
        expect(attributes.share_media_url).to be_nil
        expect(attributes.share_media_height).to be_nil
        expect(attributes.share_media_width).to be_nil
      end
    end

    describe "representative no derivative" do
      let(:work) { create(:work, representative: create(:asset, :no_derivatives_creation))}

      it "has nil values" do
        expect(attributes.share_media_url).to be_nil
        expect(attributes.share_media_height).to be_nil
        expect(attributes.share_media_width).to be_nil
      end
    end
  end

  describe "#short_plain_description" do
    it "is not html_safe" do
      expect(attributes.short_plain_description).not_to be_html_safe
    end

    it "is description" do
      expect(attributes.short_plain_description).to eq description
    end

    describe "with HTML tags in description" do
      let(:work) { create(:work, description: "This is <b>bold</b>.")}
      it "removes tags" do
        expect(attributes.short_plain_description).to eq "This is bold."
      end
    end

    describe "with very long description" do
      let(:work) { create(:work, description: ("This is a sentance. " * 400)) }
      it "truncates" do
        expect(attributes.short_plain_description.length).to be < 400
      end
    end

    describe "with empty string description" do
      let(:work) { build(:work, description: "")}
      it "is empty string" do
        expect(attributes.short_plain_description).to eq ""
      end
    end
  end

  describe "#title_plus_description" do
    it "has one" do
      expect(attributes.title_plus_description).to eq "#{attributes.page_title}: #{attributes.short_plain_description}"
    end
  end
end
