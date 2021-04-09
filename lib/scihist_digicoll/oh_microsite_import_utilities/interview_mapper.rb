# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata

require "shrine"
module OhMicrositeImportUtilities
  # Attempts to establish a mapping between interviews in the microsite and interviews in the digital collections.
  # "Ghosts", unpublished duplicate interviews in the microsite, are removed from the mapping first of all, so they can
  # be ignored for the rest of the imprort. Then we sort
  class InterviewMapper
    attr_accessor :ghosts, :no_source

    def initialize(interviews, works)
      @interviews = interviews
      @works = works

      # friendlier_ids of works with no source to migrate from:
      @no_source = []
      # unpublished duplicates we are going to ignore:
      @ghosts = []
      # friendlier_id => [interview_entity_id, interview_entity_id_2]
      @matches = {}
    end

    def construct_map()
      remove_ghost_interviews
      @works.find_each do |w|
        relevant_rows = select_rows(@interviews, w)
        if relevant_rows.empty?
          @no_source << w.friendlier_id; next
        end
        @matches[w.friendlier_id] = relevant_rows.map {|row| row['interview_entity_id']}
      end
    end

    def report()
      puts "Matches: #{@matches.keys.count}"
      the_others = unaccounted_for()
      if the_others.count < 10
        puts "Interviews with no destination work: \n #{the_others}"
      else
        puts "Interviews with no destination work: #{the_others.count}"
      end
      puts "Interviews with more than one source: #{@matches.values.select {|v| v.count > 1} }"
      puts "Ghost interviews: #{@ghosts.count}"
    end

    # The microsite contains a number of unpublished duplicate records
    # which are artefacts of an *earlier* migration.
    # Ideally, we would delete these from the microsite pre-emptively,
    # *before* attemptint the migration.
    # Removes ghost interviews from @interviews,
    # and store their `interview_entity_id` in @ghosts
    # so that we don't bother attempting to import them later on.
    def remove_ghost_interviews()
      all_interview_numbers = @interviews.map {|i| i['interview_number']}.uniq.sort
      all_interview_numbers.each do |inum|
        # the .dup is unneccessary, but makes the following easier to understand.
        ghosts =  @interviews.select { |interviewee| interviewee['interview_number'] == inum }.dup
        next if ghosts.count < 2
        # a ghost needs to be unpublished and a duplicate
        ghosts.delete_if  {|interview| interview['published'] == 1 }
        next unless ghosts.present?
        ghosts.each { |ghost| remove_ghost(ghost) }
      end
    end

    def remove_ghost(ghost)
      @ghosts << ghost['interview_entity_id']
      @interviews.delete_if {|interview| interview['interview_entity_id'] == ghost['interview_entity_id'] }
    end

    # These are interviews in the microsite
    # that have no destination interview in the digital collection
    # that we can migrate to.
    def unaccounted_for()
      migrated = @matches.values.flatten
      @interviews.select do |inte|
        !(migrated.include? inte['interview_entity_id']) && !(@ghosts.include? inte['interview_entity_id'])
      end
    end

  end
end