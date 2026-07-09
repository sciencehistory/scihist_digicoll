namespace :scihist do
  namespace :data_fixes do
    desc """
      update creator and subject headings from `Watson, James D., 1928-` to
      `Watson, James D.,1928-2025`
    """
    task :update_watson_heading => :environment do
      original_heading = "Watson, James D., 1928-"
      new_heading = "Watson, James D., 1928-2025"

      works = Work.jsonb_contains(subject: original_heading).or(Work.jsonb_contains(creator: { value: original_heading} ))

      progress_bar = ProgressBar.create(total: works.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Indexable.index_with(batching: true) do
        works.find_each(batch_size: 10) do |work|
          work.subject = work.subject.collect { |s| s == original_heading ? new_heading : s}
          work.creator.collect { |c| c.value = new_heading if c.value == original_heading }
          work.save!

          progress_bar.increment
        end
      end
    end
  end
end
