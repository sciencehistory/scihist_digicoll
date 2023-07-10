namespace :scihist do
  namespace :reports do
    desc """Output a shell script to find broken links in related links.
      #
      # bundle exec rake scihist:reports:follow_related_link_forwarding > check_forwards.sh
      #
      #./check_forwards.sh 2>/dev/null
    """
    task :follow_related_link_forwarding => :environment do
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

              # consider only "link" and "location":
              "| grep 'link\\\|location'",
              
              # find "stories"
              "| grep 'stories'",

              # and flag if found.
              "&& echo \"found in #{metadata}\""
            ]
            puts comm.join(' ')
          end
        end
      end
    end
  end
end