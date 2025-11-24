# A sort of "sidecar" object with extra Work content for Oral Histories, especially
# related to OHMS.
#
# A work optionally has_one of these. There is a unique index to make sure there
# can indeed only be one.
#
# You can do `oral_history_content = work.oral_history_content!` to create
# the 'sidecar' if it doesn't already exist, else use the existing one.
#
# The sidecar has a shrine file slot for combined audio derivatives:
# combined_audio_m4a.
#
# To store a created derivative directly to 'store' storage, you can use some custom methods,
# passing a `File` object or other shrine-compatible io-like object.
#
#     oral_history_content.set_combined_audio_m4a!(io)
#
# There is a string field `combined_audio_fingerprint` for fingerprinting
# combined files for staleness, and a JSONB field combined_audio_component_metadata
# expected to hold a hash of metadata on components of combined audio.
#
# There is a text/blob slot for the OHMS XML file, `ohms_xml_text`. It's not
# a shrine file attachment, just a postgres `text` column. At #ohms_xml is an
# object that provides access to elements from the parsed XML.
#
# ## Auto-indexing
#
# Saving an OralHistoryContent object with changes to transcript text will by default
# automatically cause solr reindex of associated work.
#
# Note this means if you are making large scale changes to OralHistoryContent objects,
# there are no performance concerns, as the naive approach might issue an individual
# SQL query for the work associated with each OralHistoryContent... and then issue
# a separate non-batched solr update for each. The solution is eager-loading
# associated works, and using kithe techniques to control auto-indexing: batch-updating,
# or turning off auto-updating.
#
class OralHistoryContent < ApplicationRecord
  include AttrJson::Record
  include AttrJson::NestedAttributes
  self.table_name = "oral_history_content"

  belongs_to :work, inverse_of: :oral_history_content

  has_and_belongs_to_many :interviewer_profiles
  has_and_belongs_to_many :interviewee_biographies

  # Delete all embedding chunks if we get deleted, should be fine `delete` instead of `destroy`,
  # we don't need callbacks?
  has_many :oral_history_chunks, inverse_of: :oral_history_content, dependent: :delete_all

  after_save :delete_chunks_on_transcript_change

  include CombinedAudioUploader::Attachment.new(:combined_audio_m4a, store: :combined_audio_derivatives)

  # Generic attachment with with no custom uploader behavior at all
  include GenericActiveRecordUploader::Attachment.new(:input_docx_transcript)
  include GenericActiveRecordUploader::Attachment.new(:output_sequenced_docx_transcript)

  enum :combined_audio_derivatives_job_status,  {
    queued:    'queued',
    started:   'started',
    failed:    'failed',
    succeeded: 'succeeded'
  }


  # Some assets marked non-published in this work are still available by request. That feature needs to be turned
  # on here at the work level, in one of two modes:
  #
  #   * automatic: after filling out request form, user gets access without human intervention
  #   * manual_review: after filling out request form, request needs to be approved by human
  #   * off: by request form feature not enabled
  #
  # Once enabled at the work level, individual assets also need their oh_available_by_request flag
  # set, for extra sure this non-published asset is meant to be available by request.
  #
  # backed by a pg enum. methods such as `available_by_request_off?` are available,
  # along with scopes like `OralHistoryContent.available_by_request_automatic`
  enum :available_by_request_mode, {off: 'off', automatic: 'automatic', manual_review: 'manual_review'}, prefix: :available_by_request

  after_commit :after_commit_update_work_index_if_needed

  # Sets IO to be combined_audio_m4a, writing directly to "store" storage,
  # and *saves model*.
  def set_combined_audio_m4a!(io)
    set_combined_audio!(combined_audio_m4a_attacher, io, mime_type: "audio/mp4", file_suffix: "m4a")
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
    return @has_ohms_transcript if defined?(@has_ohms_transcript)

    @has_ohms_transcript = begin
      transcript_text = ohms_xml&.transcript_text
      # OHMS sometimes gives you a transcript body that says "No transcript.", argh!
      transcript_text.present? && transcript_text != "No transcript."
    end
  end

  def has_ohms_index?
    @has_ohms_index ||= ohms_xml&.index_points&.present?
  end

  def combined_audio_derivatives_job_status=(value)
    super
    self.combined_audio_derivatives_job_status_changed_at = DateTime.now
  end

  private

  # Kind of hacky way to trigger reindex of work when transcripts are changed here,
  # since we now index transcripts in solr. Called in after_commit hook.
  #
  # If the last save changed the transcript, and we HAVE a work, and kithe configuration
  # is currently set up to auto-index that work... autoindex it.
  #
  # Note this means if you are making large scale changes to OralHistoryContent objects,
  # there are no performance concerns, as the naive appraoch might issue an individual
  # SQL query for the work associated with each OralHistoryContent... and then issue
  # a separate non-batched solr update for each. The solution is eager-loading
  # associated works, and using kithe techniques to control auto-indexing: batch-updating,
  # or turning off auto-updating.
  def after_commit_update_work_index_if_needed
    return unless (
      self.saved_change_to_attribute?(:ohms_xml_text) ||
      self.saved_change_to_attribute?(:searchable_transcript_source)
    )
    return unless work && Kithe::Indexable.auto_callbacks?(work)

    work.update_index
  end

  # Sets IO to given shrine attacher, writing directly to "store" storage,
  # and *saves model*.
  #
  # Trying to skip the two-stage two-copy shrine attachment process ("promotion"),
  # when the file is app backend-created, and doens't need it. But is this a mistake,
  # should we just use standard approach? This one requires *saving* the model to make
  # sure we avoid orphaned file in store.
  def set_combined_audio!(shrine_attacher, io, mime_type:, file_suffix:)
    original = shrine_attacher.get
    metadata = { "mime_type" => mime_type, "filename" => "combined.#{file_suffix}" }
    shrine_attacher.attach(io, metadata: metadata)
    self.save!
  rescue StandardError => e
    shrine_attacher.set(original)
    self.combined_audio_derivatives_job_status = "failed"
    self.save!
    raise e
  end

  def delete_chunks_on_transcript_change
    # if our transcript has changed, our chunks and embeddings are likely no longer valid, delete them.
    if saved_change_to_ohms_xml_text?
      # use delete without callbacks, it's okay and more efficient
      oral_history_chunks.delete_all
    end
  end
end
