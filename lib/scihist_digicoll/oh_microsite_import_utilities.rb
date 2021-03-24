# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata
module OhMicrositeImportUtilities
  module Updaters
    def self.name(oral_history_content, rows)
      # noop
    end
    def self.birth_date_1(oral_history_content, rows)
      # noop
    end
    def self.birth_date_2(oral_history_content, rows)
      # noop
    end
    # TODO some of hese have TIMEZONES too argh
    def self.birth_date_3(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.date = strip_time_info(rows.first[:birth_date_3])
    end
    def self.birth_city(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.city         = rows.first[:birth_city]
    end
    def self.birth_state(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.state        = rows.first[:birth_state]
    end
    def self.birth_province(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.province     = rows.first[:birth_province]
    end
    def self.birth_country(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.country      = rows.first[:birth_country]
    end
    def self.death_date_1(oral_history_content, rows)
      # noop
    end
    def self.death_date_2(oral_history_content, rows)
      # noop
    end
    def self.death_date_3(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.date         = strip_time_info(rows.first[:death_date_3])
    end
    def self.death_city(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.city         = rows.first[:death_city]
    end
    def self.death_state(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.state        = rows.first[:death_state]
    end
    def self.death_province(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.province     = rows.first[:death_province]
    end
    def self.death_country(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.country   = rows.first[:death_country]
    end

    def self.education(oral_history_content, rows)
      oral_history_content.interviewee_school            = rows.map do |row|
        OralHistoryContent::IntervieweeSchool.new(
          date:         strip_time_info(row[:date]),
          institution:  row[:school_name],
          discipline:   row[:discipline],
          degree:       row[:degree]
        )
      end
    end

    def self.career(oral_history_content, rows)
      oral_history_content.interviewee_job = rows.map do |row |
        OralHistoryContent::IntervieweeJob.new(
          start:        strip_time_info(row[:job_start_date]),
          end:          strip_time_info(row[:job_end_date]),
          institution:  row[:employer_name],
          role:         row[:job_title]
        )
      end
    end

    def self.honors(oral_history_content, rows)
      oral_history_content.interviewee_honor = rows.map do |row |
        OralHistoryContent::IntervieweeHonor.new(
          start_date:   strip_time_info(row[:interviewee_honor_start_date]),
          end_date:     strip_time_info(row[:interviewee_honor_end_date]),
          honor:        row[:interviewee_honor_description]
        )
      end
    end

  # submodule ends here
  end

  def oh_database
    Sequel.connect(
      :adapter => 'mysql2',
      :user =>     IO.read('bin/oh_microsite_export/local_database_user.txt'),
      :password => IO.read('bin/oh_microsite_export/local_database_password.txt'),
      :database => IO.read('bin/oh_microsite_export/local_database_name.txt')
    )
  end

  def select_rows(all_rows, work)
    accession_num =  work.external_id.find { |id| id.category == "interview" }&.value
    abort if accession_num.nil?
    all_rows.to_a.select{|row| row[:interview_number] == accession_num}
  end

  # Strip time of day info from all these dates.
  def strip_time_info(dt)
    dt&.to_s[0...10]
    #return nil if dt.nil?
    #date_str = dt.to_s
    #date_str[0...10]
  end

  def job_from_row(row)

  end
  def honor_from_row(row)
    # TODO: remove this delete once we merge in the migration that contains the two dates for honors.

  end
  def school_from_row(row)

  end
end