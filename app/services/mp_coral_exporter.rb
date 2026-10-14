require 'fileutils'

# Export metadata and transcripts for Max Planck CORAL project, this
# is likely a temporary need we won't use again, and this code doesn't need
# to stick around forever.
#
# https://github.com/sciencehistory/scihist_digicoll/issues/3640
class MpCoralExporter
  attr_reader :work

  # fetch all oral histories and export them, with PDF and transcript files.
  # Will take a while.
  #
  # Will export inside base_dir, with one sub dir for each OH, the subdir name
  # being friendly ID.  In that subdir is a `metadata.json` file, and possibly
  # other transcript files as mentioned in the metadata.json.
  def self.export_all(base_dir:)
    scope = Work.strict_loading.
          where("json_attributes -> 'genre' ?  'Oral histories'").
          includes("contained_by", "oral_history_content", "members")

    puts "exporting #{scope.count} in #{base_dir}"

    i = 0

    scope.find_each(batch_size: 10) do |work|
      i += 1

      dir = "#{base_dir}/#{work.friendlier_id}"
      FileUtils.mkdir_p(dir)

      work_exporter = self.new(work)

      File.write("#{dir}/metadata.json", JSON.pretty_generate(work_exporter.metadata))

      if work_exporter.pdf_transcript.present?
        File.open("#{dir}/#{work_exporter.pdf_transcript.original_filename}", "wb") do |destination_file|
          work_exporter.pdf_transcript.file.stream(destination_file)
        end
      end

      if work_exporter.ohms_transcript_filename
        File.write("#{dir}/#{work_exporter.ohms_transcript_filename}", work.oral_history_content.ohms_xml.transcript_text)
      end

      if work_exporter.auto_extracted_text_filename
        File.write("#{dir}/#{work_exporter.auto_extracted_text_filename}", JSON.pretty_generate(work.oral_history_content.extracted_paragraph_container.paragraphs.as_json))
      end

      # lazy progress indicator
      if i % 50 == 0
        print i
      else
        print "."
      end
    end
  end

  def initialize(work)
    unless work.genre.include?("Oral histories")
      raise ArgumentError.new("This is only meant for use with oral histories")
    end

    @work = work
  end

  def metadata
    {
      title: work.title,
      id: work.friendlier_id,
      permalink: "https://digital.sciencehistory.org/works/#{work.friendlier_id}",
      description: work.description,
      subjects: work.subject, # array
      media_type: work.format, # array
      interviewer: work.creator.find_all {|c| c.category == "interviewer" }.collect(&:value),
      interviewee: work.creator.find_all {|c| c.category == "interviewee" }.collect(&:value),
      place_of_interview: work.place.find_all { |p| p.category == "place_of_interview"}.collect(&:value),
      language: work.language, # array
      in_sub_collections: in_sub_collections, # array
      access_availability_mode: work.oral_history_content.availability_mode, # 'direct' is public on web, others are not
      rights_statement: work.rights,
      rights_holder: work.rights_holder,
      pdf_transcript_filename: pdf_transcript&.original_filename,
      audio_recording_filenames: audio_files.collect { |a| a.original_filename },
      ohms_transcript_filename: ohms_transcript_filename,
      auto_extracted_text_filename: auto_extracted_text_filename
    }
  end

  def in_sub_collections
    work.contained_by.
      find_all { |c| c.title != "Oral History Collection"}.
      collect do |col|
        {
          title: col.title,
          id: col.friendlier_id
        }
      end
  end

  def pdf_transcript
    work.members.find { |m| m.role == "transcript" }
  end

  def audio_files
    work.members.find_all  { |m| m.content_type.start_with?("audio/") }.sort_by(&:position)
  end

  # this is only in db it doesn't have it's own filename, we make one up
  def ohms_transcript_filename
    if work.oral_history_content.has_ohms_transcript?
      "#{work.friendlier_id}_ohms_transcript.txt"
    end
  end

  # this is only in db it doesn't have it's own filename, we make one up
  def auto_extracted_text_filename
    if work.oral_history_content.extracted_paragraph_container.present?
      "#{work.friendlier_id}_auto_extracted_text.json"
    end
  end

end
