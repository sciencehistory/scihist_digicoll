class CreateAssetOcrJob < ApplicationJob
  if ScihistDigicoll::Env.lookup("active_job_ocr_queue").present?
    queue_as ScihistDigicoll::Env.lookup("active_job_ocr_queue")
  end

  def perform(asset)
    AssetOcrCreator.new(asset).call
  end
end
