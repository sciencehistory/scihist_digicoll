# A sort of "sidecar" object with extra Work content for Oral Histories, especially
# related to OHMS.
#
# A work optionally has_one of these. There is a unique index to make sure there
# can indeed only be one.
#
# You can do `oral_history_content = work.oral_history_content!` to create
# the 'sidecar' if it doesn't already exist, else use the existing one.
#
# The sidecar has two shrine file slots for combined audio derivatives:
# combined_audio_mp3, and combined_audio_webm.
#
# To store a created derivative directly to 'store' storage, you can use some custom methods,
# passing a `File` object or other shrine-compatible io-like object.
#
#     oral_history_content.set_commbined_audio_mp3!(io)
#     oral_history_content.set_commbined_audio_webm!(io)
#
# There is a (yet-unused) string field `combined_audio_fingerprint` for fingerprinting
# combined files for staleness, and a JSONB field combined_audio_component_metadata
# expected to hold a hash of metadata on components of combined audio.
#
# There is a text/blob slot for the OHMS XML file, `ohms_xml_text`. It's not
# a shrine file attachment, just a postgres `text` column. At #ohms_xml is an
# object that provides access to elements from the parsed XML.
#
class OralHistoryContent < ApplicationRecord
  self.table_name = "oral_history_content"

  belongs_to :work, inverse_of: :oral_history_content

  include CombinedAudioUploader::Attachment.new(:combined_audio_mp3, store: :combined_audio_derivatives)
  include CombinedAudioUploader::Attachment.new(:combined_audio_webm, store: :combined_audio_derivatives)

  validates :combined_audio_derivatives_creation_status, inclusion: { in: ['STARTED', 'ERROR', 'DONE'], allow_blank: true }

  # Sets IO to be combined_audio_mp3, writing directly to "store" storage,
  # and *saves model*.
  def set_combined_audio_mp3!(io)
    set_combined_audio!(combined_audio_mp3_attacher, io, mime_type: "audio/mpeg", file_suffix: "mp3")
  end

  def set_combined_audio_webm!(io)
    set_combined_audio!(combined_audio_webm_attacher, io, mime_type: "audio/webm", file_suffix: "webm")
  end

  # A OralHistoryContent::OhmsXml object that provides access to parts of XML we need.
  #
  # Note that this is cached with whatever content is loaded, if ohmx_xml_text changes,
  # it'll be wrong. That doesn't really happen, we don't access this again right
  # after setting ohms_xml_text before a page reload.
  def ohms_xml
    return nil unless ohms_xml_text.present?
    @ohms_xml ||= OhmsXml.new(ohms_xml_text)
  end

  def has_ohms_transcript?
    @has_ohms_transcript ||= begin
      transcript_text = ohms_xml&.parsed&.at_xpath("//ohms:record/ohms:transcript[normalize-space(text())]", ohms: OhmsXml::OHMS_NS)
      # OHMS gives you a transcript body that says "No transcript.", argh!
      transcript_text && transcript_text.text != "No transcript."
    end
  end

  def has_ohms_index?
    @has_ohms_index ||= ohms_xml&.index_points&.present?
  end

  def set_combined_audio_derivatives_creation_status(status_string)
    self.combined_audio_derivatives_creation_status = status_string
    self.combined_audio_derivatives_creation_status_changed_at = DateTime.now
    self.save!
  end


  private

  # Sets IO to given shrine attacher, writing directly to "store" storage,
  # and *saves model*.
  #
  # Trying to skip the two-stage two-copy shrine attachment process ("promotion"),
  # when the file is app backend-created, and doens't need it. But is this a mistake,
  # should we just use standard approach? This one requires *saving* the model to make
  # sure we avoid orphaned file in store.
  def set_combined_audio!(shrine_attacher, io, mime_type:, file_suffix:)
    # In shrine 3.0, we may need to replacce attaccher.store! followed by attacher.set, with
    # `attacher.attach(file, storage: :store)`  Or not sure if that should be `storage: :actual_name_of_store`

    original = shrine_attacher.get
    metadata = { "mime_type" => mime_type, "filename" => "combined.#{file_suffix}" }

    if Shrine.version < Gem::Version.new("3.0")
      # shrine 2.x way of writing directly to storage
      stored_file = shrine_attacher.store!(io, metadata: metadata)
      shrine_attacher.set(stored_file)
    else
      # shrine 3.x way of writing directly to storage
      shrine_attacher.attach(io, metadata: metadata)
    end

    self.save!
  rescue StandardError => e
    # clean up file if there was a problem
    stored_file.delete if stored_file
    shrine_attacher.set(original)
    set_combined_audio_derivatives_creation_status("Error: #{e}")
    raise e
  end
end
