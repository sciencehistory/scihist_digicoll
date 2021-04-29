# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata

require "shrine"
module OhMicrositeImportUtilities
  # Attempts to establish a mapping between interviews in the microsite
  # and works in the digital collections.
  # "Ghosts", unpublished duplicate interviews in the microsite, are
  # removed from the mapping first of all, so they can
  # be ignored for the rest of the import.
  # Then we classify the remaining interviews into:
  # Matches
  # Works with no source interview (@no_source)
  # Interviews with no destination work ()
  class InterviewMapper
    attr_accessor :ghosts, :no_source

    def initialize(works)
      # interviews from the microsite database
      @names = parse_names
      # destination works
      @works = works
      # friendlier_ids of works with no source to migrate from
      @no_source = []
      # unpublished duplicates we are going to ignore
      @ghosts = []
      # friendlier_id => [interview_entity_id, interview_entity_id_2]
      @matches = {}
      # So we can keep track of any remaining mismatches and fix them
      @report = []
    end

    def construct_map
      remove_ghosts
      @works.find_each do |w|
        relevant_rows = select_rows(@names, w)
        if relevant_rows.empty?
          @no_source << w.friendlier_id
          add_to_report(work: w)
          next
        end
        relevant_rows.each do |row|
          set_up_bio(work: w, id:row['interview_entity_id'] , name:row['interviewee_name'])
          add_to_report(row:row, work: w)
        end
        @matches[w.friendlier_id] = relevant_rows.map {|row| row['interview_entity_id']}
      end
    end

    def run_report
      puts "\"Ghost\" interviews: #{@ghosts.count}"
      puts "Matches: #{@matches.keys.count}"
      puts "Works with no source interview:  #{@no_source.count}"
      no_dest = calculate_no_dest
      no_dest.each { |row| add_to_report(row: row) }
      puts "Interviews with no destination work: #{no_dest.count}"
      report_file_path = "#{files_location}/report.txt"
      File.open(report_file_path, "w") { |f| f.write @report.join("\n") }
      puts "See also #{report_file_path}."
    end

    # The microsite contains a number of unpublished duplicate records
    # which are artefacts of an *earlier* migration.
    # Ideally, we would delete these from the microsite pre-emptively,
    # *before* attemptint the migration.
    # This removes ghost interviews from @names
    # so that we don't bother attempting to import them later on.
    def remove_ghosts
      all_interview_numbers = @names.map { |i| i['interview_number'] }.uniq.sort
      all_interview_numbers.each do |interview_number|
        # the .dup is unneccessary, but does make the following easier to understand.
        ghosts =  @names.select { |interviewee| interviewee['interview_number'] == interview_number }.dup
        next if ghosts.count < 2
        # a ghost needs to be unpublished and a duplicate
        ghosts.delete_if  {|interview| interview['published'] == 1 }
        next unless ghosts.present?
        ghosts.each do |ghost|
          add_to_report(row: ghost, ghost:true)
          @ghosts << ghost['interview_entity_id']
          @names.delete_if {|interview| interview['interview_entity_id'] == ghost['interview_entity_id'] }
        end
      end
    end

    # Iterate through the source interviews to find any
    # that have no destination work in the digital collection
    # that we can migrate to.
    def calculate_no_dest
      migrated = @matches.values.flatten
      result = @names.dup
      result.delete_if { |i| migrated.include? i['interview_entity_id']}
      result.delete_if { |i| @ghosts.include?  i['interview_entity_id']}
      # just for clarity -- thew me for a loop
      result
    end

    def parse_names
      names = JSON.parse(File.read("#{files_location}/name.json"))
      unless names.is_a? Array
        puts "Error parsing names data."
        abort
      end
      @names = names
    end

    def add_to_report (row:nil, work:nil, ghost:false)
      if row.nil? && work.nil?
        "Bad item added to report."
        abort
      end
      if row.present?
        name = row['interviewee_name'].split(' ').last
        pub =  (row['published'] == 1) ? "PUBLISHED" : "NOT_PUBLISHED"
        ghost_status = ghost ? "GHOST" : "NOT_GHOST"
        source = "https://oh.sciencehistory.org/node/#{row['interview_entity_id']}/"
        dest = "NO_DEST"
      end
      # Overwrite with destination data, where possible:
      if work.present?
        name =  work.title.split(' ').last
        pub ||= (work.published?) ? "PUBLISHED" : "NOT_PUBLISHED"
        ghost_status = ghost ? "GHOST" : "NOT_GHOST"
        source ||= 'NO_SOURCE'
        dest =  "https://digital.sciencehistory.org/admin/works/#{work.friendlier_id}"
      end
      @report << [name, pub, ghost_status, source, dest].join(" ")
    end
  end
end