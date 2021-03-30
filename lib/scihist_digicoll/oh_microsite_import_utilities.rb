# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata
module OhMicrositeImportUtilities
  module Updaters
    def self.name(oral_history_content, rows)
      # noop
    end
    def self.birth_date_1(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.date = keep_yyyy_mm_dd(rows.first['birth_date_1'])
    end
    def self.birth_date_2(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.date = keep_yyyy_mm_dd(rows.first['birth_date_2'])
    end
    def self.birth_date_3(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.date = keep_yyyy_mm_dd(rows.first['birth_date_3'])
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
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.date = keep_yyyy_mm_dd(rows.first['death_date_1'])
    end
    def self.death_date_2(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.date = keep_yyyy_mm_dd(rows.first['death_date_2'])
    end
    def self.death_date_3(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.date = keep_yyyy_mm_dd(rows.first['death_date_3'])
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
      oral_history_content.interviewee_school            = rows.map do |row|
        OralHistoryContent::IntervieweeSchool.new(
          date:         keep_yyyy(row['date']),
          institution:  row['school_name'],
          discipline:   row['discipline'],
          degree:       row['degree']
        )
      end
    end

    def self.career(oral_history_content, rows)
      oral_history_content.interviewee_job = rows.map do |row |
        OralHistoryContent::IntervieweeJob.new(
          start:        keep_yyyy(row['job_start_date']),
          end:          keep_yyyy(row['job_end_date']),
          institution:  row['employer_name'],
          role:         row['job_title']
        )
      end
    end

    def self.honors(oral_history_content, rows)
      oral_history_content.interviewee_honor = rows.map do |row |
        OralHistoryContent::IntervieweeHonor.new(
          start_date:   keep_yyyy(row['interviewee_honor_start_date']),
          end_date:     keep_yyyy(row['interviewee_honor_end_date']),
          honor:        row['interviewee_honor_description']
        )
      end
    end

  # submodule ends here
  end

  def select_rows(all_rows, work)
    accession_num =  work.external_id.find { |id| id.category == "interview" }&.value
    abort if accession_num.nil?
    all_rows.to_a.select{|row| row['interview_number'] == accession_num}
  end

  # Strip time of day info from all these dates.
  def keep_yyyy_mm_dd(dt)
    dt&.to_s[0...10]
  end

  # For career / education / honor dates, we only care about years.
  def keep_yyyy(dt)
    dt&.to_s[0...4]
  end


end