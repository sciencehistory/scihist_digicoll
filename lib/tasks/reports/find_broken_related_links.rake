namespace :scihist do
  namespace :reports do
    desc """Output a shell script to find broken links in related links.
      #
      # bundle exec rake scihist:reports:find_broken_related_links > check_urls.sh
      #
      #./check_urls.sh 2>/dev/null
    """
    task :find_broken_related_links => :environment do
      Kithe::Indexable.index_with(batching: true) do
        Work.find_each do |work|
          next if work.related_link.length == 0
          work.related_link.each do |link|
            friendlier_id = work.friendlier_id
            #title = work.title
            #category = link.category
            #label = link.label
            url = link.url
            metadata =  "#{friendlier_id} #{url}"
            comm = [
              # --head:       show document info only
              # --location:   follows redirects
              # --show-error: show errors but otherwise silent mode
              # --fail-early: fail early
              "curl --head --location --show-error --fail-early #{url} ",

              # consider only the response codes:
              "| grep HTTP ",

              # ignore all but the final response code:
              "| tail -1",

              # which needs to be a 200, else return an error.
              # https://www.gnu.org/software/grep/manual/html_node/Exit-Status.html
              "| grep 200",

              # If there was a problem, show the error messsage.
              "|| echo PROBLEM: #{metadata}"
            ]
            puts comm.join(' ')
          end
        end
      end
    end
  end
end