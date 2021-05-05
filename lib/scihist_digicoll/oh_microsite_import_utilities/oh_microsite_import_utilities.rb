# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata

module OhMicrositeImportUtilities
  def files_location
    ENV['FILES_LOCATION'].nil? ? '/tmp/ohms_microsite_import_data' : ENV['FILES_LOCATION']
  end

  def get_interviewees(work)
    work.creator.select { |id| id.category == "interviewee" }.map(&:value)
  end

  def get_interviewers(work)
    work.creator.select { |id| id.category == "interviewer" }.map(&:value)
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
    %w{ education career honors image interviewer interviewer_2}
  end

  # If there's only one name in the digital collection, use that one.
  # If there's more than one name, pick the one with the same first name as the one in the microsite.
  # if you can't find that name, give up.
  #
  # Remove any trailing dates, commas and dashes.
  def name_recipe(microsite_name:, digicoll_names:)
    if digicoll_names.count == 1
      fast_name = digicoll_names.first
    else
      first_name = microsite_name.split(' ').first
      fast_name = digicoll_names.find{|n| n.include? first_name}
      if fast_name.nil?
        puts "Could not figure out a FAST name for #{microsite_name}"
        fast_name = microsite_name
      end
    end
    # I'm removing the trailing dates.
    fast_name.gsub(/[0-9 ,\-]+$/, '')
  end

  # Given an oral history and an asssociated interviewee's name and Drupal ID,
  # make sure that the work is associated with an IntervieweeBiography for that
  # interviewee.
  def set_up_bio(work:, id:, name:)
    bio = IntervieweeBiography.find_or_initialize_by(id: id)
    bio.name = name_recipe(microsite_name:name, digicoll_names:get_interviewees(work))
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

  # We only have 71 interviewers, as of the import, and these names
  # are never seen by the public. So this doesn't have to be perfect.
  # Let's resort to a quick-and-dirty recipe.
  def interviewer_name_switcher(name)
    exceptions = {
     "John Kenly Smith, Jr." => "Smith, John Kenly Jr.",
     "Peter J. T. Morris" => "Morris, Peter J. T.", # Think those are spaces? Think again.
     "David van Keuren" => "van Keuren, David"
    }
    parts = name.split(" ")
    exceptions[name] || "#{parts.last}, #{parts[0...-1].join (' ')}"
  end

end