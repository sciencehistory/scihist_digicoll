class CreateHlsVideoJob < ApplicationJob
  def perform(asset)
    CreateHlsMediaconvertJobService.new(asset).call
  end
end

