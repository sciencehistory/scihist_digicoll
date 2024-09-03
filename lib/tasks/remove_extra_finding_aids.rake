# See https://github.com/sciencehistory/scihist_digicoll/pull/2726 for context.
#
# bundle exec rake scihist:data_fixes:remove_extra_finding_aids
#
# This test is for code that is meant to be run only once - for now.
# However, we are keeping the rake task (and the service task) around in case we need it (or something like it) in the future. It's a common enough pattern.
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
