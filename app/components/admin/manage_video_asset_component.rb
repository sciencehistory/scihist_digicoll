module Admin
  class ManageVideoAssetComponent < ApplicationComponent
    attr_reader :asset

    def initialize(asset)
      unless asset.content_type&.start_with?("video/")
        raise ArgumentError.new("Can only be used with video assets, #{asset.friendlier_id} has content_type #{asset.content_type}")
      end

      @asset = asset
    end
  end
end
