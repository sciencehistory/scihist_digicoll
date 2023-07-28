class CreateAssetOcrJob < ApplicationJob
  def perform(asset)
    AssetOcrCreator.new(asset).call
  end
end
