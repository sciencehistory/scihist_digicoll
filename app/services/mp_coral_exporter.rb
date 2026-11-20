require 'fileutils'

# Export metadata and transcripts for Max Planck CORAL project, this
# is likely a temporary need we won't use again, and this code doesn't need
# to stick around forever.
#
# https://github.com/sciencehistory/scihist_digicoll/issues/3640
#
#     MpCoralExporter.new.export_all_zip_and_upload
#
class MpCoralExporter
  attr_reader :base_dir

  def initialize(base_dir: nil)
    if base_dir.nil?
      @internal_tmp_base_dir = true
      base_dir = Dir.mktmpdir(self.class.name.underscore + "_")
    end

    @base_dir = File.expand_path(base_dir)
  end


  def export_all_zip_and_upload
    export_all

    $stderr.puts
    $stderr.puts "Zipping..."
    zip_file_path = zip_directory

    $stderr.puts "Uploading to S3...."
    destination_path = "#{self.class.name.underscore}_#{ScihistDigicoll::Env.lookup(:service_level) || "UNK"}_#{Time.now.strftime('%Y%m%d_%H%M%S')}.zip"
    upload_to_cache_storage(source_path: zip_file_path, destination_path: destination_path)
  ensure
    FileUtils.rm_rf(base_dir) if @internal_tmp_base_dir
    FileUtils.rm_rf(zip_file_path) if zip_file_path
  end

  def scope
    Work.strict_loading.
      where("kithe_models.json_attributes -> 'genre' ?  'Oral histories'").
      includes("contained_by", "oral_history_content", "members").
      joins(:oral_history_content).
      # everything exccepting: embarboed AND excepting some additional exclusions
      where("oral_history_content.availability_mode != 'embargoed'").
      where.not(friendlier_id: EXCLUDED_FRIENDLIER_IDS)
  end

  # fetch all oral histories and export them, with PDF and transcript files.
  # Will take a while.
  #
  # Will export inside base_dir, with one sub dir for each OH, the subdir name
  # being friendly ID.  In that subdir is a `metadata.json` file, and possibly
  # other transcript files as mentioned in the metadata.json.
  def export_all
    puts "exporting #{scope.count} in #{base_dir}"

    i = 0

    scope.find_each(batch_size: 10) do |work|
      i += 1

      dir = "#{base_dir}/#{work.friendlier_id}"
      FileUtils.mkdir_p(dir)

      work_exporter = Entry.new(work)

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

  def zip_directory
    dir = base_dir

    tmp_file = Tempfile.new(["coral_export_#{Time.now.strftime('%Y%m%d_%H%M%S')}", ".zip"])

    Zip::File.open(tmp_file.path, create: true) do |zip|
      Dir.glob("**/*", File::FNM_DOTMATCH, base: dir).each do |relative|
        next if relative == "." || relative.end_with?("/.")

        full = File.join(dir, relative)
        if File.directory?(full)
          zip.mkdir(relative)
        else
          zip.add(relative, full)
        end
      end
    end

    return tmp_file.path
  end

  def upload_to_cache_storage(source_path:, destination_path:)
    storage = ScihistDigicoll::Env.shrine_cache_storage

    File.open(source_path, "rb") { |io| storage.upload(io, destination_path) }

    if storage.respond_to?(:bucket)
      $stderr.puts "Uploaded s3://#{storage.bucket.name}/#{storage.object(destination_path).key}"
    else
      $stderr.puts "Uploaded #{zip_name} to #{storage}"
    end
  end

  class Entry
    attr_reader :work

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
        find_all { |c| c.title.downcase != "oral history collection"}.
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


  # list of 42 friendlier ID's to be excluded from export, per
  # https://github.com/sciencehistory/scihist_digicoll/issues/3640#issuecomment-6270462088
  EXCLUDED_FRIENDLIER_IDS = %w{
    bkxtllo
    80u8jkw
    yhw3xmt
    vlbd155
    gldoidp
    49j2s7t
    8l5lv0f
    1oqu7tu
    uthde6e
    pihpigh
    nt3xy69
    bjw01wt
    8o6ohiw
    9jg58qw
    z7ywtug
    dk3bga5
    nmciejn
    ln6wfev
    33iy8by
    owj874z
    13g67ah
    bwv8gvz
    2y5oqt1
    cb8liyu
    c8mmpws
    rwg0whl
    uwitvhe
    xz0icab
    fz55iu8
    ckikh2w
    z9ml4ow
    t8n11bc
    kp1aay6
    o89oyep
    7rucjam
    t89tifg
    5hzc2z1
    79q4gwv
    9y9exj9
    3umab6c
    uu5l29a
    pwm7ovn
  }

end
