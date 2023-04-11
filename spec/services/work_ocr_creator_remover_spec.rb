require 'rails_helper'

describe WorkOcrCreatorRemover, queue_adapter: :test do
  let(:image_asset_without_hocr) { create(:asset_with_faked_file) }
  let(:image_asset_with_hocr)    { create(:asset_with_faked_file, hocr: "goat") }
  let(:sound_asset) { create(:asset_with_faked_file, :m4a) }
  let(:child_work)  { create(:public_work, representative: create(:asset_with_faked_file)) }

  let(:work) do
    create(:public_work,
      language: 'English',
      ocr_requested: ocr_requested,
      members: [
        image_asset_without_hocr,
        image_asset_with_hocr,
        sound_asset,
        child_work
      ]
    )
  end

  let(:asset_hocr_creator_mock) { instance_double(AssetHocrCreator, call: 'result') }

  context "work needs OCR soon (the rake task calls this.)" do
    let(:ocr_requested) { true }
    it "enqueues an ocr creation job for assets that need it" do
      WorkOcrCreatorRemover.new(work).process
      expect(CreateAssetHocrJob).to have_been_enqueued.with(image_asset_without_hocr)
      expect(CreateAssetHocrJob).not_to have_been_enqueued.with(image_asset_with_hocr)
      expect(CreateAssetHocrJob).not_to have_been_enqueued.with(sound_asset)
      expect(CreateAssetHocrJob).not_to have_been_enqueued.with(child_work)
    end
  end

  context "work needs all OCR recreated soon" do
    let(:ocr_requested) { true }
    it "enqueues an ocr creation job for all image assets" do
      WorkOcrCreatorRemover.new(work, overwrite_existing_ocr: true).process
      expect(CreateAssetHocrJob).to have_been_enqueued.with(image_asset_without_hocr)
      expect(CreateAssetHocrJob).to have_been_enqueued.with(image_asset_with_hocr)
      expect(CreateAssetHocrJob).not_to have_been_enqueued.with(sound_asset)
      expect(CreateAssetHocrJob).not_to have_been_enqueued.with(child_work)
    end
  end

  context "work needs OCR immediately" do
    let(:ocr_requested) { true }
    it "calls AssetHocrCreator immediately, inline." do
      allow(AssetHocrCreator).to receive(:new).and_return(asset_hocr_creator_mock)
      WorkOcrCreatorRemover.new(work, do_now: true).process
      expect(asset_hocr_creator_mock).to have_received(:call)
      work.members.each do |m|
        expect(CreateAssetHocrJob).not_to have_been_enqueued.with(m)
      end
    end
  end

  context "work does not need OCR" do
    let(:ocr_requested) { false }
    it "removes OCR" do
      WorkOcrCreatorRemover.new(work).process
      work.reload
      work.members.each do |m|
        expect(CreateAssetHocrJob).not_to have_been_enqueued.with(m)
        expect(m.hocr).to be_nil if m.asset?
      end
    end
  end
end
