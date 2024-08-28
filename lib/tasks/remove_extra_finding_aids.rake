# See https://github.com/sciencehistory/scihist_digicoll/pull/2726 for context.

# This test is for code that will be run only once:
# lib/tasks/remove_extra_finding_aids.rake

# We will need to delete it after we run this code.

namespace :scihist do
  namespace :data_fixes do
    desc "Remove duplicate finding aids on child works and works that are in collections"
    # bundle exec rake scihist:data_fixes:remove_extra_finding_aids

    task :remove_extra_finding_aids => :environment do
      scope = Work.where("json_attributes -> 'department' ?  'Archives'")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      notes = []
      Work.transaction do
        Kithe::Indexable.index_with(batching: true) do
          scope.find_each do |work|
            remover = ExtraFindingAidRemover.new(work)
            remover.process
            notes << remover.notes unless remover.notes.empty?
            progress_bar.increment
          end
        end
      end
      puts notes.join("\n")
    end
  end
end
