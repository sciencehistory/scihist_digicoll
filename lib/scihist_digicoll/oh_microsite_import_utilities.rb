# Utility methods for oral history microsite import.
# See:
# scihist:oh_microsite_import:import_interviewee_biographical_metadata


require "shrine"
require "shrine/storage/file_system"
require "down"



module OhMicrositeImportUtilities
  module Updaters

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

  # submodule ends here
  end

  def select_rows(all_rows, work)
    accession_num =  work.external_id.find { |id| id.category == "interview" }&.value
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
        role: portrait,
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