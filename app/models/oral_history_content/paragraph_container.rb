require 'digest'

class OralHistoryContent
  # A serializable container for paragraphs plus some source/provenance metadata
  # about them!
  #
  # Includes logic for fingerprinting and checking freshness etc.
  class ParagraphContainer
    include AttrJson::Model

    attr_json :paragraphs, OralHistoryContent::Paragraph.to_type, array: true

    attr_json :created_at, :datetime, default: -> { Time.current.utc }

    # fingerprints to tell freshness and provenance
    attr_json :pdf_md5, :string
    attr_json :audio_start_times_md5, :string

    # Git SHA just for additional provenance
    attr_json :source_version, :string


    def self.create(pdf_asset:, oral_history_content:, paragraphs:)
      self.new(
        paragraphs: paragraphs,
        source_version: ENV['SOURCE_VERSION'],
        pdf_md5: pdf_asset.file_metadata["md5"],
        audio_start_times_md5: fingerprint_audio_start_times(oral_history_content: oral_history_content)
      )
    end

    def self.fingerprint_audio_start_times(oral_history_content:)
      Digest::MD5.hexdigest(oral_history_content.combined_audio_component_metadata["start_times"].to_json)
    end

    def fresh?(oral_history_content:, pdf_asset:)
      pdf_md5 == pdf_asset.file_metadata["md5"] &&
      audio_start_times_md5 == self.class.fingerprint_audio_start_times(oral_history_content: oral_history_content)
    end
  end
end

