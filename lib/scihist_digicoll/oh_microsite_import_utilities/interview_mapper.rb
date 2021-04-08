# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata

require "shrine"

module OhMicrositeImportUtilities

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

  # Strip time of day info from all these dates.
  def keep_yyyy_mm_dd(dt)
    return nil if dt.nil?
    dt&.to_s[0...10]
  end

  # For career / education / honor dates, we only care about years.
  def keep_yyyy(dt)
    dt&.to_s[0...4]
  end

  class InterviewMapper
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

    def unaccounted_for()
      migrated = @matches.values.flatten
      @interviews.select do |inte|
        id = inte['interview_entity_id']
        !migrated.include?(id) && !@ghosts.include?(id)
      end
    end

    def construct_map()
      remove_ghost_interviews()
      @works.find_each do |w|
        accession_num =  get_accession_number(w)
        next unless accession_num
        relevant_rows = @interviews.to_a.select{|row| row['interview_number'] == accession_num}
        if relevant_rows.empty?
          @no_source << w.friendlier_id
          next
        end
        @matches[w.friendlier_id] =  relevant_rows.map {|row| row['interview_entity_id']}
      end
    end

    # there's a keyworkd for this, attr_getter or soemthing TODO
    def ghosts()
      @ghosts
    end

    def no_source()
      @no_source
    end

    def report()
      puts "Matches: #{@matches.keys.count}"
      the_others = unaccounted_for()
      if the_others.count < 50
        puts "Interviews with no destination work: \n #{the_others}"
      else
        puts "Interviews with no destination work: #{the_others.count}"
      end
      puts "Interviews with more than one source: #{@matches.values.select {|v| v.count > 1} }"
      puts "Ghost interviews: #{@ghosts.count}"
    end

    # The microsite contains a number of unpublished duplicate records
    # which are artefacts of an *earlier* migration.
    def remove_ghost_interviews()
      all_interview_numbers = @interviews.map {|i| i['interview_number']}.uniq.sort
      all_interview_numbers.each do |inum|
        ghosts =  @interviews.select { |interviewee| interviewee['interview_number'] == inum }
        next if ghosts.count < 2
        # a ghost needs to be unpublished and a duplicate
        ghosts.delete_if  {|interview| interview['published'] == 1 }
        next unless ghosts.present?
        ghosts.each do |ghost|
          @interviews.delete_if {|interview| interview['interview_entity_id'] == ghost['interview_entity_id'] }
          @ghosts << ghost['interview_entity_id']
        end
      end
    end
  end

  class IntervieweePortraitUploader
    attr_accessor :work, :download_source, :title, :alt, :caption

    def initialize(args)
      @work     = args[:work]
      @filename = args[:filename]
      @url      = args[:url]
      @title    = args[:title]
      @alt      = args[:alt]
      @caption  = args[:caption]
    end

    # Try creating a portrait if none exists.
    def maybe_upload_file
      return unless portrait_asset.nil?
      portrait = new_portrait()
      if portrait.save
        @work.representative = portrait
        @work.save
      end
    end

    # If the portrait already exists, update its metadata
    def maybe_update_metadata
      return if portrait_asset.nil?
      portrait_asset.title = @title
      # and so on ...
    end

    def new_portrait
      portrait = Asset.new(
        title: @title,
        position: next_open_position,
        parent_id: @work.id,
        published: @work.published,
        role: 'portrait',
        )
        portrait.file_attacher.set_promotion_directives(promote: "inline")
        portrait.file_attacher.set_promotion_directives(create_derivatives: "inline")
        begin
          portrait.file = { "id" => @url, "storage" => "remote_url" }
        rescue Shrine::Error => shrine_error
          puts("Shrine error: #{shrine_error}")
        end
      portrait
    end

    def next_open_position
      work.members.map{|mem| mem.position.to_i}.max + 1
    end

    def portrait_asset
      work.members.find {|mem| mem.attributes['role'] == 'portrait'}
    end
  end


end