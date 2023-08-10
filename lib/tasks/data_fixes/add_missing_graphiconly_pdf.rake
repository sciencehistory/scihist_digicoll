namespace :scihist do
  namespace :data_fixes do
    desc """
      Enqueues a jobs to special_workers for any image assets missing graphiconly_pdf
      derivative
    """

    task :add_missing_graphiconly_pdf => :environment do
      scope = Asset.where("file_data -> 'metadata' ->> 'mime_type' = 'image/tiff'")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      jobs_enqueued = 0;

      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |asset|
          if asset.file_derivatives[:graphiconly_pdf].blank?
            Kithe::CreateDerivativesJob.set(queue: 'special_jobs').perform_later(asset, only: :graphiconly_pdf, lazy: true)
            jobs_enqueued += 1
          end

          progress_bar.increment
        end
      end

      puts "Enqueued #{jobs_enqueued} jobs for missing graphiconly_derivaties, to special_jobs queue"

    end
  end
end
