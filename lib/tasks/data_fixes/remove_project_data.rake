namespace :scihist do
  namespace :data_fixes do
    # We'll be removing the "project" attribute altogether, first
    # remove the data.
    task :remove_project_data => :environment do
      progress_bar =  ProgressBar.create(total: Work.count, format: Kithe::STANDARD_PROGRESS_BAR_FORMAT)
      Kithe::Indexable.index_with(batching: true) do
        Work.find_each do |work|
          # actually a bit hard to completely remove this key from the DB,
          # instead of just having it be an empty array cast per current data
          # types! This seems to work. And will have the benefit of continuing
          # to work AFTER the project attr is really removed too.
          #
          # There would have been a way to do this in a single raw SQL if
          # we really wanted to.
          if work.json_attributes.has_key?("project")
            work.json_attributes.delete("project")
            work.save!
          end
          progress_bar.increment
        end
      end
    end
  end
end
