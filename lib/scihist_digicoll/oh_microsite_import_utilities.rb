# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata

require "shrine"

module OhMicrositeImportUtilities
  module Updaters

    def self.birth_date(oral_history_content, rows)
      oral_history_content.interviewee_birth ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_birth.date = keep_yyyy_mm_dd(rows.first['birth_date'])
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

    def self.death_date(oral_history_content, rows)
      oral_history_content.interviewee_death ||= OralHistoryContent::DateAndPlace.new
      oral_history_content.interviewee_death.date = keep_yyyy_mm_dd(rows.first['death_date'])
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
      sanitizer = DescriptionSanitizer.new()
      oral_history_content.interviewee_honor = rows.map do |row |
        args = {
          start_date:   keep_yyyy(row['interviewee_honor_start_date']),
          honor:        sanitizer.sanitize(row['interviewee_honor_description'])
        }
        if row['interviewee_honor_start_date'] != row['interviewee_honor_end_date']
          args[:end_date] = keep_yyyy(row['interviewee_honor_end_date'])
        end
        OralHistoryContent::IntervieweeHonor.new(args)
      end
    end

    def self.interviewer(oral_history_content, rows)
      profiles = InterviewerProfile.find(rows.map {|r| r['interviewer_id']})
      oral_history_content.interviewer_profiles = profiles
    end

    def self.image(oral_history_content, rows)
      uploader  = IntervieweePortraitUploader.new({
        work: oral_history_content.work,
        filename: rows.first['filename'],
        url:      rows.first['url'],
        title:    rows.first['title'],
        alt:      rows.first['alt'],
        caption:  rows.first['caption']
      })
      uploader.maybe_upload_file
      uploader.maybe_update_metadata
    end


  # submodule ends here
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

  # Strip time of day info from all these dates.
  def keep_yyyy_mm_dd(dt)
    return nil if dt.nil?
    dt&.to_s[0...10]
  end

  # For career / education / honor dates, we only care about years.
  def keep_yyyy(dt)
    dt&.to_s[0...4]
  end

  class MicrositeInterviews

    def initialize(all_items)
      @all_items = all_items
      @unpublished_duplicates = {}
      @will_be_migrated = {}
    end

    def record_unpublished_duplicate(row, work)
      @unpublished_duplicates[row['interview_entity_id']] = [work, row]
    end

    def record_match(row, work)
      @will_be_migrated[row['interview_entity_id']] = [work, row]
    end

    def unpublished_duplicate_node_ids()
      @unpublished_duplicates.keys()
    end

    def other_interviews_with_no_destination_record()
      others = []
      items_to_ignore = @unpublished_duplicates.keys() + @will_be_migrated.keys()
      @all_items.each do |row|
        others << row unless items_to_ignore.include? row['interview_entity_id']
      end
      others
    end

    def print_statistics()
      puts "All microsite interviews: #{@all_items.count}"
      puts "Unpublished duplicate interviews in the microsite: #{@unpublished_duplicates.count}"
      puts "Other microsite interviews with no destination record:"
      # puts other_interviews_with_no_destination_record()
    end

  end


  class MappingErrors

    def initialize()
      @less_than_one_match_errors = []
      @double_match_errors = {}
      @no_accession_number_errors = []
    end

    def include?(work)
      return true if @no_accession_number_errors.include? work.friendlier_id
      return true if @less_than_one_match_errors.include? work.friendlier_id
      return true if @double_match_errors.keys().include? work.friendlier_id
      false
    end

    def record_no_accession_number(work)
      @no_accession_number_errors << work.friendlier_id
    end

    def record_no_match(work)
      @less_than_one_match_errors << work.friendlier_id
    end

    def record_double_match(work, metadata)
      @double_match_errors[work.friendlier_id] = metadata
    end

    def print_errors_and_guesses(names)
      @no_accession_number_errors.each do |id|
        w = Work.find_by_friendlier_id(id)
        puts  "#{w.title} (#{w.friendlier_id}): no accession number."
      end
      puts ""
      @less_than_one_match_errors.each do |id|
        w = Work.find_by_friendlier_id(id)
        puts  "#{w.title} (#{w.friendlier_id}): could not find source record with ID \"#{get_accession_number(w)}\"."
        potential_matches =  names.select {|row| row['interviewee_name'].include?(get_interviewee(w).split(/\W+/)[0] ) }
        if potential_matches.present?
          puts "Potential matches:"
          potential_matches.each {|ma| puts "    #{ma['source_url']}: #{ma['interviewee_name']} (#{ma['interview_number']}) " }
        end
      end
      puts ""
      @double_match_errors.each do | id, v |
        w = Work.find_by_friendlier_id(id)
        puts  "#{w.title} (#{w.friendlier_id}): more than one source record with ID \"#{get_accession_number(w)}\"\:\n#{v.join("\n")}\n\n"
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
        sleep 5
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