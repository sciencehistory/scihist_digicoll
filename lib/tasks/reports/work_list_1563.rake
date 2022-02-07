namespace :scihist do
  namespace :reports do
    # https://github.com/sciencehistory/scihist_digicoll/issues/1563
    task :work_list_1563 => :environment do
      # CSV to stdout, so we can just capture it via heroku run.
      #
      #     heroku run rake scihist:reports:work_list_1563 > report.csv
      #
      # We may have to hand-edit out some log lines that get in there.
      CSV($stdout.dup) do |csv|

        # no child works
        Work.where("parent_id is NULL").find_each do |work|
          csv << ([
           work.title,
           "https://digital.sciencehistory.org/works/#{work.friendlier_id}",
           work.genre&.join("; "),
           work.creator&.collect(&:value)&.join("; ")
          ])
        end
      end
    end
  end
end
