namespace :scihist do
  desc """
    bundle exec rake scihist:create_or_remove_ocr
  """
  task :create_or_remove_ocr => :environment do
    progress_bar = ProgressBar.create(total: Work.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    ignore_missing_files = (ENV['ignore_missing_files'] == 'true')
    Work.find_each(batch_size: 10) do |work|
      WorkOcrCreatorRemover.new(work, ignore_missing_files:ignore_missing_files).process
      progress_bar.increment
    end
  end
end
