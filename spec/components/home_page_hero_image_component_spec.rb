require 'rails_helper'

describe HomePageHeroImageComponent, type: :component do
  let(:instance) { HomePageHeroImageComponent.new(override: override) }
  let(:all_metadata) { instance.class.all_images_metadata }
  let(:override) { nil }

  describe "smoke test" do
    it "renders" do
      expect(render_inline(instance)).to have_selector('.hero-image')
    end
  end

  describe "tick = 0" do
    before do
      allow(instance).to receive(:tick).and_return(0)
    end
    it "renders placeholder" do
      expect(instance.link_title).to eq all_metadata[0]['link_title']
    end
  end

  describe "tick = 1" do
    before do
      allow(instance).to receive(:tick).and_return(1)
    end
    it "renders placeholder" do
      expect(instance.link_title).to eq all_metadata[1]['link_title']
    end
  end

  describe "tick = all_metadata.length * 300 + 2" do
    before do
      allow(instance).to receive(:tick).and_return(all_metadata.length * 300 + 2)
    end
    it "renders correct image" do
      expect(instance.link_title).to eq all_metadata[2]['link_title']
    end
  end

  describe "override is 1" do
    let(:override) { "1" }
    before do
      allow(instance).to receive(:tick).and_return(3)
    end
    it "renders correct image" do
      expect(instance.link_title).to eq all_metadata[override.to_i - 1]['link_title']
    end
  end

  describe "override can't be parsed as an int" do
    let(:override) { "goat" }
    before do
      allow(instance).to receive(:tick).and_return(4)
    end
    it "ignores override" do
      expect(instance.link_title).to eq all_metadata[4]['link_title']
    end
  end

  describe "negative override" do
    let(:override) { "-3" }
    before do
      allow(instance).to receive(:tick).and_return(5)
    end
    it "ignores override" do
      expect(instance.link_title).to eq all_metadata[5]['link_title']
    end
  end

  describe "large override" do
    let(:override) { "900" }
    before do
      allow(instance).to receive(:tick).and_return(all_metadata.length)
    end
    it "ignores override" do
      expect(instance.link_title).to eq all_metadata[0]['link_title']
    end
  end
end