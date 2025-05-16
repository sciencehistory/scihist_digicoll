class DeleteDziJob < ApplicationJob
  def perform(dzi_file_id, storage_key)
    DziPackage.delete(dzi_file_id, storage_key: storage_key)
  end
end
