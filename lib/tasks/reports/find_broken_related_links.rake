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
            urls_followed = [link.url]

            # Follow the redirect chain until we reach a 200:
            while response = HTTP.get(urls_followed.last)


              if response.status.to_i == 301
                # construct the next URL in the redirect chain
                if response.headers["Location"].start_with? 'http'
                  urls_followed.append response.headers["Location"]
                else # relative URL
                  parsed_url = URI(urls_followed.last)
                  urls_followed.append(
                    parsed_url.scheme + "://" + parsed_url.hostname  +
                    response.headers["Location"]
                  )
                end


              elsif response.status.to_i == 200
                # The chain ends in a 200; examine the end of the url
                ending = urls_followed.last.split('/').last
                if bad_endings.include? ending
                  puts "BAD redirect for #{work.friendlier_id}: #{urls_followed.first} redirects to a URL ending in #{ending}"
                else
                  puts "GOOD #{ending}"
                end
                break


              else # oh no! the chain ends in  a bad URL.
                puts "BAD response for #{work.friendlier_id}: #{urls_followed.first} leads to broken URL #{urls_followed.last}"
                break
              end

            end
          end
        end
      end
    end
  end
end