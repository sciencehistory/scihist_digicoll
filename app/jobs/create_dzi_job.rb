class CreateDziJob < ApplicationJob
  def perform(asset)
    DziManagement.new(asset).create
  end
end
