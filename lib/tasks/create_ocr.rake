namespace :scihist do
  desc """
    bundle exec rake scihist:create_or_remove_ocr
  """
  task :create_or_remove_ocr => :environment do
    progress_bar = ProgressBar.create(total: Work.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")
    Work.find_each(batch_size: 10) do |work|
      WorkOcrCreatorRemover.new(work, do_now: true).process
      progress_bar.increment
    end
  end
end
