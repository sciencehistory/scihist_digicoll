class CreateDziJob < ApplicationJob
  def perform(asset)
    DziPackage.new(asset).create
  end
end
