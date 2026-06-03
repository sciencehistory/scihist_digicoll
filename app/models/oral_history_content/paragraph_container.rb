require 'digest'

class OralHistoryContent
  # A serializable container for paragraphs plus some source/provenance metadata
  # about them!
  #
  # Includes logic for fingerprinting and checking freshness etc.
  class ParagraphContainer
    include AttrJson::Model

    attr_json_config(unknown_key: :strip)

    attr_json :paragraphs, OralHistoryContent::Paragraph.to_type, array: true

    attr_json :warnings, :string, array: true

    attr_json :created_at, :datetime, default: -> { Time.current.utc }

    # Add this offset to logical page number to get physical page number
    attr_json :logical_page_number_offset, :integer

    # start times that go with fingerprint to calculate offsets from transcript
    # Array of arrays.
    attr_json :file_start_times, ActiveModel::Type::Value.new

    # fingerprints to tell freshness and provenance
    attr_json :pdf_md5, :string
    attr_json :combined_audio_fingerprint, :string


    # Git SHA just for additional provenance
    attr_json :source_version, :string


    # Will fetch associated work and members to fingerprint and store fingerprinting
    # metadata
    #
    # Will do computational work of calculating paragraphs from stored extracted_pdf_text_json
    # derivative.
    def self.create(oral_history_content:, allow_failure_to_sync: false)
      work = oral_history_content.work
      pdf_asset = oral_history_content.work.members.find { |a| a.respond_to?(:role) && a.role == "transcript" }

      unless pdf_asset
        raise "#{self.class.name}#create: Could not find a pdf file for OralHistory for work #{work.friendlier_id}"
      end

      extracted_pdf_text_json = pdf_asset.file_derivatives[:extracted_pdf_text_json]

      unless extracted_pdf_text_json
        raise "#{self.class.name}#create: could not find extracted_pdf_text_json derivative from asset #{pdf_asset.friendlier_id}"
      end

      extracted_pdf_text = JSON.parse(extracted_pdf_text_json.read)

      # We use the CombinedAudioDerivativeCreator for calculating current audio file
      # fingerprints and start-time metadata.
      combined_audio = CombinedAudioDerivativeCreator.new(work)
      pdf_md5 = pdf_asset.file_metadata["md5"]
      combined_audio_fingerprint = combined_audio.fingerprint
      file_start_times = combined_audio.calculate_start_times

      splitter = OralHistory::PdfParagraphSplitter.new(
        extracted_pdf_text: extracted_pdf_text,
        file_start_times: file_start_times.to_h,
        allow_failure_to_sync: allow_failure_to_sync
      )

      paragraphs = splitter.paragraphs
      warnings = splitter.warnings

      container = OralHistoryContent::ParagraphContainer.new(
        paragraphs: paragraphs,
        logical_page_number_offset: splitter.logical_page_number_offset,
        source_version: ENV['SOURCE_VERSION'],
        pdf_md5: pdf_md5,
        file_start_times: file_start_times,
        combined_audio_fingerprint: combined_audio_fingerprint
      )
      container.warnings = warnings if warnings

      # And save it in the model passed in
      oral_history_content.extracted_paragraph_container = container
      oral_history_content.save!

      return container
    end

    # our sources are the PDF itself and the audio file start times, so
    # use those as fingerprint.
    def source_fingerprint
      @source_fingerprint ||= {
        "pdf_md5" => self.pdf_md5,
        "combined_audio_fingerprint" => self.combined_audio_fingerprint
      }
    end

    # Will fetch the work#members if not already fetched. Fingerprinting includes
    # audio files as well as PDF becuase the audio file lengths are used to calculate
    # offsets for some internal timestamps.
    def fresh?(oral_history_content:)
      combined_audio = CombinedAudioDerivativeCreator.new(oral_history_content.work)
      pdf_asset = oral_history_content.work.members.find { |a| a.respond_to?(:role) && a.role == "transcript" }

      self.source_fingerprint == {
        "pdf_md5" => pdf_asset.file_metadata&.dig("md5"),
        "combined_audio_fingerprint" => combined_audio.fingerprint
      }
    end
  end
end

