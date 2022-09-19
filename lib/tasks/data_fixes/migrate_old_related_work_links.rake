namespace :scihist do
  namespace :data_fixes do
    desc """
      Migrate legacy related work links with /concern/generic_works/

      They were migrated over to new related_links in somewhat corrupt fashion as other_internal
    """

    task :migrate_old_related_works_links => :environment do
      scope = Work.jsonb_contains("related_link.category" => "other_internal")

      progress_bar = ProgressBar.create(total: scope.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)

      Kithe::Indexable.index_with(batching: true) do
        scope.find_each do |work|
          related_links = work.related_link.dup
          work.related_link.each do |rl|
            if rl.url =~ %r{\Ahttps://digital.sciencehistory.org/concern/generic_works/([^/]+)$}
              rl.category = "related_work"
              rl.url = "https://digital.sciencehistory.org/works/#{$1}"

              work.save!
            end
          end

          progress_bar.increment
        end
      end
    end
  end
end
