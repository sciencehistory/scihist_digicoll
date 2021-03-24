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
    def self.birth_date_3(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.date = strip_time_info(rows.first['birth_date_3'])
    end
    def self.birth_city(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.city         = rows.first['birth_city']
    end
    def self.birth_state(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.state        = rows.first['birth_state']
    end
    def self.birth_province(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.province     = rows.first['birth_province']
    end
    def self.birth_country(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.country      = rows.first['birth_country']
    end
    def self.death_date_1(oral_history_content, rows)
      # noop
    end
    def self.death_date_2(oral_history_content, rows)
      # noop
    end
    def self.death_date_3(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.date         = strip_time_info(rows.first['death_date_3'])
    end
    def self.death_city(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.city         = rows.first['death_city']
    end
    def self.death_state(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.state        = rows.first['death_state']
    end
    def self.death_province(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.province     = rows.first['death_province']
    end
    def self.death_country(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.country   = rows.first['death_country']
    end

    def self.education(oral_history_content, rows)
      oral_history_content.interviewee_school            = rows.map { |row| school_from_row(row) }
    end
    def self.career(oral_history_content, rows)
      oral_history_content.interviewee_job              = rows.map { |row | job_from_row(row) }
    end
    def self.honors(oral_history_content, rows)
      oral_history_content.interviewee_honor            = rows.map { |row | honor_from_row(row) }
    end
  end
    # Strip time of day info from all these dates.
  def strip_time_info(date_str)
    date_str&.
      gsub(/\.000000$/, '')&.
      gsub(/ 00:00:00$/, '') #&.
      # gsub(/-01-01$/, '')
  end

  def job_from_row(row)
    OralHistoryContent::IntervieweeJob.new(
      start:        strip_time_info(row['job_start_date']),
      end:          strip_time_info(row['job_end_date']),
      institution:  row['employer_name'],
      role:         row['job_title']
    )
  end
  def honor_from_row(row)
    # TODO: remove this delete once we merge in the migration that contains the two dates for honors.
    row.delete('interviewee_honor_end_date') if row['interviewee_honor_end_date'] == row['interviewee_honor_start_date']
    OralHistoryContent::IntervieweeHonor.new(
      start_date:   strip_time_info(row['interviewee_honor_start_date']),
      end_date:     strip_time_info(row['interviewee_honor_end_date']),
      honor:        row['interviewee_honor_description']
    )
  end
  def school_from_row(row)
    OralHistoryContent::IntervieweeSchool.new(
      date:         strip_time_info(row['date']),
      institution:  row['school_name'],
      discipline:   row['discipline'],
      degree:       row['degree']
    )
  end
end