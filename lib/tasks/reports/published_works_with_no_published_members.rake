namespace :scihist do
  namespace :reports do
    desc "Published works with no published members. bundle exec rake scihist:reports:published_works_with_no_published_members"
    task :published_works_with_no_published_members => :environment do
      oral_histories = Work.where("json_attributes -> 'genre' @> ?", "\"Oral histories\"")


      Work.where(published: true).find_each do |work|
        next if oral_histories.include? work
        if work.members.all? {|m| m.published == false }
          puts "https://digital.sciencehistory.org/admin/works/#{work.friendlier_id}"
        end
      end
    end
  end
end

