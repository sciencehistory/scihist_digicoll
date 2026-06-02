namespace :scihist do
  desc """
    bundle exec rake scihist:create_oral_history_chunks
    OVERWRITE_CHUNKS=true bundle exec rake scihist:create_oral_history_chunks

    Will enqueue jobs to special_jobs queue, to create OralHistoryChunks for all
    allowed oral histories

    By default will do it lazily only for those which have no chunks, but
    `OVERWRITE_CHUNKS=true` to delete and re-create any existing chunks.

    `USE_DUMMY_EMBEDDING=true` for a test run where you want to create chunk records
    (usually in staging) without actually getting an embedding vector from remote API.

    `ONLY_EXTRACTED_PDF_PARAGRAPHS=true` limit to only those with extracted_paragraph_container present

    `ONLY_AVAILABLE_IMMEDATE=true` limit to only those available immediate ('really free access')

    `ONLY_INVALID=true` validate including source_fingerprint and only create for ones that are
        invalid/stale , implies OVERWRITE_CHUNKS.

  """
  task :create_oral_history_chunks => [:environment] do
    scope = OralHistoryContent.preload(:work => :members).joins(:work).where(work: { published: true}).strict_loading

    if ENV['ONLY_EXTRACTED_PDF_PARAGRAPHS'] == "true"
      scope = scope.where("oral_history_content.json_attributes -> 'extracted_paragraph_container' is not NULL")
    end

    if ENV['ONLY_AVAILABLE_IMMEDATE'] == "true"
      scope = scope.available_immediate
    end

    total_count = scope.count

    # include fingerprints with performant SELECT,
    # have to do after we take 'count' cause it will mess up the count
    only_invalid = (ENV['ONLY_INVALID'] == "true")
    if only_invalid
      scope = OralHistory::ChunkValidator.with_uniq_source_fingerprints(scope)
      # merge in new includes for additional stuff we'll need to check
      scope = scope.preload(:oral_history_chunks)
    end

    progress_bar = ProgressBar.create(total: total_count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

    skipped_count = 0
    enqueued_count = 0


    scope.find_each(batch_size: 10) do |oh_content|
      progress_bar.increment

      overwrite_chunks = (ENV['OVERWRITE_CHUNKS'] == "true") || only_invalid
      use_dummy_embedding = ENV['USE_DUMMY_EMBEDDING'] == "true"

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

      if only_invalid
        unless OralHistory::ChunkValidator.new(oh_content, check_source_fingerprints: true).validate
          skipped_count +=1
          next
        end
      end

      if oh_content.oral_history_chunks.exists? && !overwrite_chunks
        skipped_count += 1
        next
      end

      # enqueue to special_jobs so we can control concurrency to avoid rate limit
      OhTranscriptChunkerJob.set(queue: "special_jobs").perform_later(oral_history_content: oh_content, delete_existing: overwrite_chunks, use_dummy_embedding: use_dummy_embedding)

      enqueued_count += 1

      # try to keep from blowing up our memory with so much pre-fetching
      GC.start
    end

    puts "skipped #{skipped_count} and enqueued #{enqueued_count} of #{total_count}"
  end
end
