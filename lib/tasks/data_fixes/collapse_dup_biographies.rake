namespace :scihist do
  namespace :data_fixes do
    desc "de-duplicate dup'd IntervieweeBiographies"
    task :dedup_interviewee_biographies => :environment do
      latest_date = lambda do |bio|
        bio.oral_history_content.collect(&:work).collect(&:date_of_work).flatten.collect(&:start).max || "0"
      end

      work_ids_for_bio = lambda do |bio|
        bio.oral_history_content&.collect(&:work)&.flatten&.collect(&:friendlier_id).join(",")
      end

      dup_names = IntervieweeBiography.select(:name).group(:name).having("count(*) > 1").pluck(:name)
      puts "dup_names: #{dup_names}"

      dup_names.each do |name|
        bios = IntervieweeBiography.where(name: name).to_a

        # sort by last date of associated interview
        bios = bios.sort_by do |bio|
          latest_date.call(bio)
        end

        # delete all but last one
        if ENV['DRY_RUN']
          kept = bios.pop
          puts "#{name}: Will keep one with work date: #{latest_date.call(kept)} #{work_ids_for_bio.call(kept)}"
          puts "   dropping ones with work dates:"
          bios.each do |b|
            puts "    #{latest_date.call(b)} #{work_ids_for_bio.call(b)}"
            puts
          end
        else
          kept = bios.pop
          bad_bios = bios

          OralHistoryContent.transaction do
            oh_contents = bad_bios.collect(&:oral_history_content).flatten
            oh_contents.each do |ohc|
              bad_bios.each { |bad_bio| ohc.interviewee_biographies.delete(bad_bio) }
              unless ohc.interviewee_biographies.include?(kept)
                ohc.interviewee_biographies << kept
              end
            end

            bad_bios.each(&:destroy)
          end
        end
      end
    end
  end
end
