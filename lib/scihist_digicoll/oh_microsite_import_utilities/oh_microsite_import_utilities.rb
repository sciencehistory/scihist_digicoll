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

  # Given an oral history and an asssociated interviewee's name and Drupal ID,
  # make sure that the work is associated with an IntervieweeBiography for that
  # interviewee.
  def set_up_bio(work:, id:, name:)
    bio = IntervieweeBiography.find_or_initialize_by(id: id)
    bio.name = name
    unless bio.oral_history_content.include? work.oral_history_content
      bio.oral_history_content << work.oral_history_content
    end
    bio.save!
    work.oral_history_content.save!
  end

  # Given a set of metadata for one or more interviewees, look up the pertinent
  # bios, and use them as the keys of a hash:
  # {bio_for_person_a => [[job data],[another job data][third job data], ... ] ...}
  def get_bios(rows)
    result = {}
    rows.map {|r| r['interview_entity_id']}.sort.uniq.each do |id|
      result[IntervieweeBiography.find(id)] = rows.filter {|r| id == r['interview_entity_id']}
    end
    result
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