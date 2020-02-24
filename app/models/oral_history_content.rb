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
#     oral_history_content.set_commbined_audio_mp3(io)
#     oral_history_content.set_commbined_audio_webm(io)
#
# There is a string field `combined_audio_fingerprint` for fingerprinting
# combined files for staleness, and a JSONB filed combined_audio_component_timecodes
# expected to hold a hash of metadata on components of combined audio.
#
# There is a text/blob slot for the OHMS XML file, `ohms_xml`. It's not
# a shrine file attachment, just a postgres `text` column.
#
class OralHistoryContent < ApplicationRecord
  self.table_name = "oral_history_content"

  belongs_to :work, inverse_of: :oral_history_content

  include CombinedAudioUploader::Attachment.new(:combined_audio_mp3, store: :combined_audio_derivatives)
  include CombinedAudioUploader::Attachment.new(:combined_audio_webm, store: :combined_audio_derivatives)

  # Sets IO to be combined_audio_mp3, writing directly to "store" storage,
  # and *saves model*.
  def set_combined_audio_mp3!(io)
    set_combined_audio!(combined_audio_mp3_attacher, io, mime_type: "audio/mpeg", file_suffix: "mp3")
  end

  def set_combined_audio_webm!(io)
    set_combined_audio!(combined_audio_webm_attacher, io, mime_type: "audio/webm", file_suffix: "webm")
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
    original = shrine_attacher.get
    stored_file = shrine_attacher.store!(io, metadata: {"mime_type" => mime_type, "filename" => "combined.#{file_suffix}"})
    shrine_attacher.set(stored_file)
    self.save!
  rescue StandardError => e
    # clean up file if there was a problem
    stored_file.delete if stored_file
    shrine_attacher.set(original)
    raise e
  end

end
