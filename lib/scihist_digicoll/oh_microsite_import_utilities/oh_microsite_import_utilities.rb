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

  def works_we_want(args)
    return Kithe::Work.where(friendlier_id: args.to_a) if args.to_a.present?
    Kithe::Work.where("json_attributes -> 'genre' ?  'Oral histories'")
  end

  def metadata_files
    %w{ birth_date birth_city birth_state birth_province birth_country } +
    %w{ death_date death_city death_state death_province death_country } +
    %w{ education career honors image interviewer}
  end

  def final_reporting(errors, works_updated)
    if errors.present?
      puts "#{errors.join("\n")}"
    else
      puts "No validation errors."
    end
    puts "Works updated: #{works_updated.count}"
  end

end