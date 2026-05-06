namespace :scihist do
  # fix off by one, our chunk paragraph numbers are supposed to start at 1, but
  # some started at zero
  task :fix_chunk_paragraph_numbers => :environment do
    scope = OralHistoryContent
    progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

    scope.find_each(batch_size: 100) do |oral_history_content|
      first_chunk = oral_history_content.oral_history_chunks.order(:start_paragraph_number).first

      if first_chunk.present? && first_chunk.start_paragraph_number == 0
        # no! supposed to be 1
        # We can use SQL to n = n+1 em all in one blow.
        oral_history_content.oral_history_chunks.
          update_all("start_paragraph_number = start_paragraph_number + 1, end_paragraph_number = end_paragraph_number + 1")
      end

      progress_bar.increment
    end
  end
end
