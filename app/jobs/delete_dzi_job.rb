class DeleteDziJob < ApplicationJob
  def perform(dzi_file_id, storage_key)
    DziFiles.delete(dzi_file_id, storage_key: storage_key)
  end
end
