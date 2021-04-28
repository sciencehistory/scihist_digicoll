# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata

require 'scihist_digicoll/oh_microsite_import_utilities/interviewee_portrait_uploader'

module OhMicrositeImportUtilities

  # Strip time of day info from all these dates.
  def keep_yyyy_mm_dd(dt)
    return nil if dt.nil?
    dt&.to_s[0...10]
  end

  # For career / education / honor dates, we only care about years.
  def keep_yyyy(dt)
    return nil if dt.nil?
    dt&.to_s[0...4]
  end

  # These methods each take an OralHistoryContent item, and an array of
  # hashes (rows). In addition to the metadata used to actually update the
  # OralHistoryContent, each hash also contains four extra rows for debugging:
  # interviewee_name
  # interviewee_entity_id (the Drupal node number,
  #      the unique ID used by drupal to identify the interview
  # interview_number (the key we use to match source and destination records
  # published (whether or not the interview is published).
  #
  # Example of a row passed to the `honors` method below:
  # {
  #   "interviewee_name":"Tadeus Reichstein",
  #   "interview_entity_id":5262, # this is
  #   "interview_number":"0040",
  #   "published":1
  #   "interviewee_honor_description":"<p>Marcel-Benoist Prize</p>",
  #   "interviewee_honor_start_date":"1947-01-01 00:00:00",
  #   "interviewee_honor_end_date":"1947-01-01 00:00:00",
  # },

  module Updaters
    def self.birth_date(w, rows, transformations: nil)
      rows.each do |row|
        bio = IntervieweeBiography.find(row['interview_entity_id'])
        bio.birth ||= OralHistoryContent::DateAndPlace.new
        bio.birth.date = keep_yyyy_mm_dd(row['birth_date'])
        bio.save!
      end
    end

    def self.birth_city(w, rows, transformations: nil)
      rows.each do |row|
        bio = IntervieweeBiography.find(row['interview_entity_id'])
        bio.birth ||= OralHistoryContent::DateAndPlace.new
        bio.birth.city = row['birth_city']
        bio.save!
      end
    end

    def self.birth_state(w, rows, transformations: nil)
      rows.each do |row|
        bio = IntervieweeBiography.find(row['interview_entity_id'])
        bio.birth ||= OralHistoryContent::DateAndPlace.new
        bio.birth.state = row['birth_state']
        bio.save!
      end
    end

    def self.birth_province(w, rows, transformations: nil)
      rows.each do |row|
        bio = IntervieweeBiography.find(row['interview_entity_id'])
        bio.birth ||= OralHistoryContent::DateAndPlace.new
        bio.birth.province     = row['birth_province']
        bio.save!
      end
    end

    def self.birth_country(w, rows, transformations: nil)
      rows.each do |row|
        bio = IntervieweeBiography.find(row['interview_entity_id'])
        bio.birth ||= OralHistoryContent::DateAndPlace.new
        bio.birth.country = row['birth_country']
        bio.save!
      end
    end

    def self.death_date(w, rows, transformations: nil)
      rows.each do |row|
        bio = IntervieweeBiography.find(row['interview_entity_id'])
        bio.death ||= OralHistoryContent::DateAndPlace.new
        bio.death.date = keep_yyyy_mm_dd(row['death_date'])
        bio.save!
      end
    end

    def self.death_city(w, rows, transformations: nil)
      rows.each do |row|
        bio = IntervieweeBiography.find(row['interview_entity_id'])
        bio.death ||= OralHistoryContent::DateAndPlace.new
        bio.death.city = row['death_city']
        bio.save!
      end
    end

    def self.death_state(w, rows, transformations: nil)
      rows.each do |row|
        bio = IntervieweeBiography.find(row['interview_entity_id'])
        bio.death ||= OralHistoryContent::DateAndPlace.new
        bio.death.state = row['death_state']
        bio.save!
      end
    end

    def self.death_province(w, rows, transformations: nil)
      rows.each do |row|
        bio = IntervieweeBiography.find(row['interview_entity_id'])
        bio.death ||= OralHistoryContent::DateAndPlace.new
        bio.death.province = row['death_province']
        bio.save!
      end
    end

    def self.death_country(w, rows, transformations: nil)
      rows.each do |row|
        bio = IntervieweeBiography.find(row['interview_entity_id'])
        bio.death ||= OralHistoryContent::DateAndPlace.new
        bio.death.country = row['death_country']
        bio.save!
      end
    end

    def self.education(w, rows, transformations: nil)
      get_bios(rows).each_pair do |bio, bio_rows|
        bio.school = bio_rows.map do |row|
          institution = row['school_name']
          if transformations.present? && transformations[institution].present?
            institution = transformations[institution]
          end
          OralHistoryContent::IntervieweeSchool.new(
            date:         keep_yyyy(row['date']),
            institution:  institution,
            discipline:   row['discipline'],
            degree:       row['degree']
          )
        end
        bio.save!
      end
    end

    def self.career(w, rows, transformations: nil)
      get_bios(rows).each_pair do |bio, bio_rows|
        bio.job = bio_rows.map do |row |
          institution = row['employer_name']
          if transformations.present? && transformations[institution].present?
            institution = transformations[institution]
          end
          OralHistoryContent::IntervieweeJob.new(
            start:        keep_yyyy(row['job_start_date']),
            end:          keep_yyyy(row['job_end_date']),
            institution:  institution,
            role:         row['job_title']
          )
        end
        bio.save!
      end
    end

    def self.honors(w, rows, transformations: nil)
      sanitizer = DescriptionSanitizer.new
      get_bios(rows).each_pair do |bio, bio_rows|
        honors = bio_rows.map do |row |
          args = {
            start_date:   keep_yyyy(row['interviewee_honor_start_date']),
            honor:        sanitizer.sanitize(row['interviewee_honor_description'])
          }
          if row['interviewee_honor_start_date'] != row['interviewee_honor_end_date']
            args[:end_date] = keep_yyyy(row['interviewee_honor_end_date'])
          end

          if args.values.all?(&:nil?)
            nil
          else
            OralHistoryContent::IntervieweeHonor.new(args)
          end
        end
        bio.honor = honors.compact
        bio.save!
      end
    end


    # We are only migrating associations with interviewers who actually have bios.
    # The list of interviewer names is already stored in the creator field of the Work.
    def self.interviewer(w, rows, transformations: nil)
      profiles = InterviewerProfile.where(id: rows.map {|r| r['interviewer_id']})
      w.oral_history_content.interviewer_profiles = profiles
      w.oral_history_content.save!
    end

    def self.image(w, rows, transformations: nil)
      row = rows.first
      uploader  = IntervieweePortraitUploader.new({
        work:     w,
        filename: row['filename'],
        url:      row['url'],
        title:    row['title'],
        alt_text: row['alt'],
        caption:  row['caption']
      })
      uploader.maybe_upload_file
      uploader.maybe_update_metadata
    end
  end
end