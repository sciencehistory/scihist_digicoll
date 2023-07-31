namespace :scihist do
  namespace :reports do
    desc """
      # bundle exec rake scihist:reports:find_broken_related_links 
    """
    task :find_broken_related_links => :environment do
      # a) Report related links that are, or redirect to, a broken URL.

      # b) In addition, if the final URL of the rediect chain ends in one of these endings,
      # we want to report it as a problem:
      bad_endings = ['stories', 'magazine', 'distillations-pod']
      Kithe::Indexable.index_with(batching: true) do
        Work.find_each do |work|
          next if work.related_link.length == 0
          work.related_link.each do |link|
            begin
              response = HTTP.follow.get(link.url)
              ending_of_last_url = response.uri.to_s.split('/').last
              status_of_last_url = response.status.to_i
              if status_of_last_url != 200
                puts "BAD status   for #{work.friendlier_id}: #{link.url} redirects to status #{status_of_last_url}"
              elsif bad_endings.include? ending_of_last_url
                puts "BAD redirect for #{work.friendlier_id}: #{link.url} redirects to a URL ending in #{ending_of_last_url}"
              else
                puts "GOOD #{ending_of_last_url}"
              end
            rescue HTTP::Error  => e
              puts "BAD #{e} thrown following #{work.friendlier_id}: #{link.url}"
            end
          end
        end
      end
    end
  end
end