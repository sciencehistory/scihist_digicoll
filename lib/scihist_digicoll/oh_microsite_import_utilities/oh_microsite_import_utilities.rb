# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata

module OhMicrositeImportUtilities
  def files_location
    ENV['FILES_LOCATION'].nil? ? '/tmp/ohms_microsite_import_data' : ENV['FILES_LOCATION']
  end

  def get_interviewee(work)
    work.creator.find { |id| id.category == "interviewee" }&.value
  end

  def get_accession_number(work)
    work.external_id.find { |id| id.category == "interview" }&.value
  end

  def select_rows(all_rows, work)
    accession_num = get_accession_number(work)
    abort if accession_num.nil?
    all_rows.to_a.select{|row| row['interview_number'] == accession_num}
  end
end