class CreateAssetHocrJob < ApplicationJob
  def perform(asset)
    AssetHocrCreator.new(asset).call
  end
end
