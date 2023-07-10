namespace :scihist do
  namespace :reports do
    desc "List of oral histories without bib numbers. bundle exec rake scihist:reports:oral_histories_without_bib_numbers > report.csv"
    task :oral_histories_without_bib_numbers => :environment do
      oral_histories = Work.where("json_attributes -> 'genre' @> ?", "\"Oral histories\"")
      cmd = TTY::Command.new(output: Logger.new("/dev/null"))
      work_columns = ["title", "friendlier_id"]
      oral_histories.find_each do |oral_history_work|
        next unless url = oral_history_work&.oral_history_content&.combined_audio_m4a&.url
        next unless oral_history_work.external_id.count {|id| id.category == 'bib'} == 0
        puts "https://digital.sciencehistory.org/admin/works/#{oral_history_work.friendlier_id}/edit"
      end
    end
  end
end