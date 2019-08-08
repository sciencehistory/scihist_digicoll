class DeleteDziJob < ApplicationJob
  def perform(dzi_file_id)
    DziFiles.delete(dzi_file_id)
  end
end
