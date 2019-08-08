class CreateDziJob < ApplicationJob
  def perform(asset)
    DziFiles.new(asset).create
  end
end
