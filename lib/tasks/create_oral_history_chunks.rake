namespace :scihist do
  desc """
    bundle exec rake scihist:create_oral_history_chunks
    OVERWRITE_CHUNKS=true bundle exec rake scihist:create_oral_history_chunks

    Will enqueue jobs to special_jobs queue, to create OralHistoryChunks for all
    allowed oral histories

    By default will do it lazily only for those which have no chunks, but
    `OVERWRITE_CHUNKS=true` to delete and re-create any existing chunks.
  """
  task :create_oral_history_chunks => [:environment] do
    scope = OralHistoryContent.includes(:work => :members).joins(:work).where(work: { published: true})
    total_count = scope.count

    progress_bar = ProgressBar.create(total: total_count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

    skipped_count = 0
    enqueued_count = 0


    scope.find_each do |oh_content|
      progress_bar.increment

      overwrite_chunks = ENV['OVERWRITE_CHUNKS'] == "true"

      # Make sure we skip truly embargoed/non-public stuff, which is
      # currently a bit tricky in the metadata.
      # See https://github.com/sciencehistory/scihist_digicoll/issues/3253
      if oh_content.available_by_request_off?
        # Not requestable, but does it have a published transcript? If not, no go
        unless oh_content.work.members.to_a.find {|asset| asset.role == "transcript" && asset.published?}
          skipped_count += 1
          next
        end
      end

      if oh_content.oral_history_chunks.exists? && !overwrite_chunks
        skipped_count += 1
        next
      end

      enqueued_count += 1

      # enqueue to special_jobs so we can control concurrency to avoid rate limit
      OhTranscriptChunkerJob.set(queue: "special_jobs").perform_later(oh_content, delete_existing: overwrite_chunks)
    end

    puts "skipped #{skipped_count} and enqueued #{enqueued_count} of #{total_count}"
  end
end
