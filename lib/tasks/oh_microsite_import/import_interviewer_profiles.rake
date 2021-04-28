namespace :scihist do
  namespace :oh_microsite_import do
    require 'scihist_digicoll/oh_microsite_import_utilities/oh_microsite_import_utilities'
    include OhMicrositeImportUtilities

    desc """
      Creates interviewer profiles based on data
      extracted from JSON files in a particular directory.

      Expected locations:

      /tmp/ohms_microsite_import_data/interviewer_profile.json

      bundle exec rake scihist:oh_microsite_import:import_interviewer_profiles

      This code assumes that:
        there are no interviewer profiles in the DB before our first import
        any interviewer profiles that do exist are ours to destroy at our pleasure

      Based on these assumptions, we allow ourselves to explicitly set ActiveRecord database
      ids on these to the same id as the source record.

    """
    task :import_interviewer_profiles => :environment do |t, args|
      errors = []
      profiles = JSON.parse(File.read("#{files_location}/interviewer_profile.json"))
      progress_bar = ProgressBar.create(
        total: profiles.count,
        format: "%a %t: |%B| %R/s %c/%u %p%% %e",
        title: "interviewer profiles"
      )
      sanitizer = DescriptionSanitizer.new()
      profiles.each do |profile|
        profile_text = sanitizer.sanitize(profile['interviewer_profile'])
        if profile_text.blank?
          # There's no point in these profiles unless an interviewer actually has a profile.
          progress_bar.increment
          next
        end
        begin
          prof = InterviewerProfile.find_or_initialize_by(id: profile['interviewer_id'])
          prof.name = interviewer_name_switcher(profile['interviewer_name'])
          prof.profile = profile_text
          prof.save!
        rescue StandardError => e
          progress_bar.log("ERROR: #{profile['interviewer_name']}: unable to save: #{e.inspect}")
          next
        end
        progress_bar.increment
      end
      puts "\nThere are now #{InterviewerProfile.count} interviewer profiles."
    end
  end
end