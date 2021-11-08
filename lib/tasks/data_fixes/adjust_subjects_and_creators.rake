require "#{Rails.root}/lib/scihist_digicoll/task_helpers/subject_creator_adjuster"
namespace :scihist do
  namespace :data_fixes do
    desc "Subject and creator changes to match name authorities, per https://github.com/sciencehistory/scihist_digicoll/issues/1432"
    task :adjust_subjects_and_creators => :environment do
      progress_bar = ProgressBar.create(total: Work.count, format: "%a %t: |%B| %R/s %c/%u %p%% %e")      
      adjuster = ScihistDigicoll::TaskHelpers::SubjectCreatorAdjuster.new
      Work.transaction do
        Kithe::Indexable.index_with(batching: true) do
          Work.find_each(batch_size: 10) do |work|
            adjuster.process_work(work)
            progress_bar.increment
          end
        end
      end
      puts "Changes:"
      pp adjuster.changes
      puts "Errors:"
      pp adjuster.errors
    end
  end
end