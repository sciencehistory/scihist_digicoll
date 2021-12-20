require 'rails_helper'

describe "published_at" do
  let(:asset) do
    create(:asset, published: false,  published_at: nil)
  end
  let(:work) do
    create(:work, :published, published: false, published_at: nil)
  end
  let(:collection) do
    create(:collection, published: false,  published_at: nil)
  end

  describe "sets published at" do
    around do |example|
      freeze_time do
        example.run
      end
    end

    it "when a work is published" do
      work.update(published: true)
      expect(work.published_at).to eq Time.now
    end
    it "when an asset is published" do
      asset.update(published: true)
      expect(asset.published_at).to eq Time.now
    end
    it "when a collection is published" do
      collection.update(published: true)
      expect(collection.published_at).to eq Time.now
    end
  end
end
