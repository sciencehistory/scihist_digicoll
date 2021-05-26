namespace :scihist do
  namespace :data_fixes do
    desc "Remove empty IntervieweeBiography objects"
    task :remove_empty_biographies => :environment do
      IntervieweeBiography.find_each do |bio|
        if (bio.birth.blank? && bio.death.blank? &&
              (bio.school.blank?  || bio.school.all?(&:blank?)) &&
              (bio.job.blank?  || bio.job.all?(&:blank?)) &&
              (bio.honor.blank?  || bio.honor.all?(&:blank?))
              )
          if ENV['DRY_RUN']
            puts "#{bio.id}:#{bio.name}"
          else
            bio.destroy!
          end
        end
      end
    end
  end
end
