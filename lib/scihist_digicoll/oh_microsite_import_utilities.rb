# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata
module OhMicrositeImportUtilities
  def clean_up_date_string(date_str)
    date_str&.
      gsub(/\.000000$/, '')&.
      gsub(/ 00:00:00$/, '')&.
      gsub(/-01-01$/, '')
  end

  def job_from_row(row)
    OralHistoryContent::IntervieweeJob.new(
      start:        clean_up_date_string(row['job_start_date']),
      end:          clean_up_date_string(row['job_end_date']),
      institution:  row['employer_name'],
      role:         row['job_title']
    )
  end

  def honor_from_row(row)
    row.delete('interviewee_honor_end_date') if row['interviewee_honor_end_date'] == row['interviewee_honor_start_date']
    OralHistoryContent::IntervieweeHonor.new(
      start_date:   clean_up_date_string(row['interviewee_honor_start_date']),
      end_date:     clean_up_date_string(row['interviewee_honor_end_date']),
      honor:        row['interviewee_honor_description']
    )
  end

  def school_from_row(row)
    OralHistoryContent::IntervieweeSchool.new(
      date:         clean_up_date_string(row['date']),
      institution:  row['school_name'],
      discipline:   row['discipline'],
      degree:       row['degree']
    )
  end
end