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
    def self.birth_date(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.date = keep_yyyy_mm_dd(rows.first['birth_date'])
    end

    def self.birth_city(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.city         = rows.first['birth_city']
    end

    def self.birth_state(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.state        = rows.first['birth_state']
    end

    def self.birth_province(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.province     = rows.first['birth_province']
    end

    def self.birth_country(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.country      = rows.first['birth_country']
    end

    def self.death_date(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.date = keep_yyyy_mm_dd(rows.first['death_date'])
    end

    def self.death_city(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.city         = rows.first['death_city']
    end

    def self.death_state(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.state        = rows.first['death_state']
    end

    def self.death_province(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.province     = rows.first['death_province']
    end

    def self.death_country(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.country   = rows.first['death_country']
    end

    def self.education(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_school            = rows.map do |row|
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
    end

    def self.career(oral_history_content, rows, transformations: nil)
      oral_history_content.interviewee_job = rows.map do |row |
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
    end

    def self.honors(oral_history_content, rows, transformations: nil)
      sanitizer = DescriptionSanitizer.new

      honors = rows.map do |row |
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

      oral_history_content.interviewee_honor = honors.compact
    end


    # We are only migrating associations with interviewers who actually have bios.
    # The list of interviewer names is already stored in the creator field of the Work.
    def self.interviewer(oral_history_content, rows, transformations: nil)
      profiles = InterviewerProfile.where(id: rows.map {|r| r['interviewer_id']})
      oral_history_content.interviewer_profiles = profiles
    end

    def self.image(oral_history_content, rows, transformations: nil)
      uploader  = IntervieweePortraitUploader.new({
        work: oral_history_content.work,
        filename: rows.first['filename'],
        url:      rows.first['url'],
        title:    rows.first['title'],
        alt_text: rows.first['alt'],
        caption:  rows.first['caption']
      })
      uploader.maybe_upload_file
      uploader.maybe_update_metadata
    end
  end
end