class DeleteDziJob < ApplicationJob
  def perform(dzi_file_id)
    DziManagement.delete(dzi_file_id)
  end
end
