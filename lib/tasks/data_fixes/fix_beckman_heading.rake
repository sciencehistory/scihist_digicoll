namespace :scihist do
  namespace :data_fixes do
    desc "fix 'Beckman Instruments, inc.' to 'Inc.'"
    task :fix_beckman_heading => :environment do
      total = Work.jsonb_contains("creator.value" =>  "Beckman Instruments, inc.").count + Work.jsonb_contains("subject" =>  "Beckman Instruments, Inc.").count

      progress_bar = ProgressBar.create(total: total, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Indexable.index_with(batching: true) do
        Work.jsonb_contains("subject" =>  "Beckman Instruments, inc.").find_each do |work|
          work.subject.collect! { |s| s == "Beckman Instruments, inc." ? "Beckman Instruments, Inc." : s}
          work.save!

          progress_bar.increment
        end

        Work.jsonb_contains("creator.value" =>  "Beckman Instruments, inc.").find_each do |work|
          work.creator.each do |creator|
            if creator.value == "Beckman Instruments, inc."
              creator.value = "Beckman Instruments, Inc."
            end
            work.save!
          end

          progress_bar.increment
        end
      end
    end
  end
end
