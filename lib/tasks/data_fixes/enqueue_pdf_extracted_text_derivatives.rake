namespace :scihist do
  namespace :data_fixes do

    desc """
      Enqueue jobs in 'special_jobs' to make extracted_pdf_text_json derivative for all PDF assets
    """
    task :enqueue_pdf_extacted_text_derivatives => [:environment] do
      scope = Asset.where("file_data -> 'metadata' ->> 'mime_type' = 'application/pdf'")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)


      scope.find_each do |asset|
        Kithe::CreateDerivativesJob.set(queue: "special_jobs").
          perform_later(asset, only: :extracted_pdf_text_json, lazy: true)
        progress_bar.increment
      end
    end
  end
end
