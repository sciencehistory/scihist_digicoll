namespace :scihist do
  namespace :data_fixes do
    # We'll be removing the "project" attribute altogether, first
    # remove the data.
    task :remove_project_data => :environment do
      Work.find_each do |work|
        # actually a bit hard to completely remove this key from the DB,
        # instead of just having it be an empty array cast per current data
        # types! This seems to work. And will have the benefit of continuing
        # to work AFTER the project attr is really removed too.
        #
        # There would have been a way to do this in a single raw SQL if
        # we really wanted to.
        work.json_attributes.delete("project")
        work.save!
      end
    end
  end
end
