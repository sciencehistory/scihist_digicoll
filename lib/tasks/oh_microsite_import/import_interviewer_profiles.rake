namespace :scihist do
  namespace :oh_microsite_import do
    require 'scihist_digicoll/oh_microsite_import_utilities'
    include OhMicrositeImportUtilities
    desc """
      Creates interviewer profiles based on data
      extracted from JSON files in a particular directory.

      Expected locations:

      /tmp/ohms_microsite_import_data/interviewer_profile.json

      bundle exec rake scihist:oh_microsite_import:import_interviewer_profiles

      # To specify another location for files:
      # FILES_LOCATION=/tmp/some_other_dir/ bundle exec rake scihist:oh_microsite_import:import_interviewer_profiles

      This code assumes that:
        there are no interviewer profiles in the DB before our first import
        any interviewer profiles that do exist are ours to destroy at our pleasure

      Based on these assumptions, we allow ourselves to explicitly set ActiveRecord database
      ids on these to the same id as the source record.

    """
    task :import_interviewer_profiles => :environment do |t, args|
      files_location = ENV['FILES_LOCATION'].nil? ? '/tmp/ohms_microsite_import_data/' : ENV['FILES_LOCATION']
      errors = []
      profiles = JSON.parse(File.read("#{files_location}/interviewer_profile.json"))
      progress_bar = ProgressBar.create(
        total: profiles.count,
        format: "%a %t: |%B| %R/s %c/%u %p%% %e",
        title: "interviewer profiles"
      )
      sanitizer = DescriptionSanitizer.new()
      profiles.each do |profile|
        # Validation problem: profile
        # can't be blank in destination,
        # but it is often blank in the source.
        profile_text = sanitizer.sanitize(profile['interviewer_profile'])
        profile_text = "No profile for this interviewer." if profile_text.blank?
        begin
          prof = InterviewerProfile.find_or_initialize_by(id: profile['interviewer_id'])
          prof.name =  profile['interviewer_name']
          prof.profile = profile_text
          prof.save!
        rescue StandardError => e
          progress_bar.log("ERROR: #{profile['interviewer_name']}: unable to save: #{e.inspect}")
          next
        end
        progress_bar.increment
      end
      puts "There are now #{InterviewerProfile.count} interviewer profiles."
    end
  end
end