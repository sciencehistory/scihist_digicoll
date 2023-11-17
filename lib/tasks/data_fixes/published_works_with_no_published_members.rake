namespace :scihist do
  namespace :data_fixes do
    desc """Published works with no published members.
    DRY_RUN=true bundle exec rake scihist:data_fixes:published_works_with_no_published_members
    """
    task :published_works_with_no_published_members => :environment do
      if ENV['DRY_RUN'] == "true"
        puts "Starting dry run"
      end

      oral_histories = Work.where("json_attributes -> 'genre' @> ?", "\"Oral histories\"")

      Kithe::Indexable.index_with(batching: true) do
        Work.where(published: true).find_each do |work|
          next if oral_histories.include? work
          if work.members.all? {|m| m.published == false }
            puts " - https://digital.sciencehistory.org/admin/works/#{work.friendlier_id} (#{work.title})"
            unless ENV['DRY_RUN'] == "true"
              work.members.each { |m| m.update( { published:true } ) }
            end
          end
        end
      end
    end
  end
end

