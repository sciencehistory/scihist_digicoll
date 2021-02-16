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
# ## Auto-indexing
#
# Saving an OralHistoryContent object with changes to transcript text will by default
# automatically cause solr reindex of associated work.
#
# Note this means if you are making large scale changes to OralHistoryContent objects,
# there are no performance concerns, as the naive appraoch might issue an individual
# SQL query for the work associated with each OralHistoryContent... and then issue
# a separate non-batched solr update for each. The solution is eager-loading
# associated works, and using kithe techniques to control auto-indexing: batch-updating,
# or turning off auto-updating.
#
require 'attr_json'
class OralHistoryContent < ApplicationRecord
  include AttrJson::Record
  self.table_name = "oral_history_content"

  belongs_to :work, inverse_of: :oral_history_content

  include CombinedAudioUploader::Attachment.new(:combined_audio_mp3, store: :combined_audio_derivatives)
  include CombinedAudioUploader::Attachment.new(:combined_audio_webm, store: :combined_audio_derivatives)

  enum combined_audio_derivatives_job_status: {
    queued:    'queued',
    started:   'started',
    failed:    'failed',
    succeeded: 'succeeded'
  }


  attr_json :interviewee_birth,    OralHistoryContent::IntervieweeBirth.to_type, default: -> {}
  attr_json :interviewee_death,    OralHistoryContent::IntervieweeDeath.to_type, default: -> {}

  attr_json :interviewee_school,  OralHistoryContent::IntervieweeSchool.to_type, array: true, default: -> {[]}
  attr_json :interviewee_job,     OralHistoryContent::IntervieweeJob.to_type,    array: true, default: -> {[]}
  attr_json :interviewee_honor,   OralHistoryContent::IntervieweeHonor.to_type,  array: true, default: -> {[]}

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
  enum available_by_request_mode: {off: 'off', automatic: 'automatic', manual_review: 'manual_review'}, _prefix: :available_by_request

  after_commit :after_commit_update_work_index_if_needed

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


  def combined_audio_derivatives_job_status=(value)
    super
    self.combined_audio_derivatives_job_status_changed_at = DateTime.now
  end

  def interviewee_birth_place
    birth = interviewee_date.find { |d| d.to_h['category'] == 'birth'}
    return nil if birth.nil?
    return birth.to_h['place']
  end
  def interviewee_birth_date
    birth = interviewee_date.find { |d| d.to_h['category'] == 'birth'}
    return nil if birth.nil?
    return birth.to_h['date']
  end
  def interviewee_death_place
    death = interviewee_date.find { |d| d.to_h['category'] == 'death'}
    return nil if death.nil?
    return death.to_h['place']
  end
  def interviewee_death_date
    death = interviewee_date.find { |d| d.to_h['category'] == 'death'}
    return nil if death.nil?
    return death.to_h['date']
  end

  def interviewee_schools_sorted
    return interviewee_school.sort_by { |hsh| hsh.to_h[:date] }
  end

  def interviewee_awards_sorted
    return interviewee_honor.sort_by { |hsh| hsh.to_h[:date] }
  end

  def interviewee_jobs_sorted
    return interviewee_job.sort_by { |hsh| hsh.to_h[:start] }
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
    self.combined_audio_derivatives_job_status = "failed"
    self.save!
    raise e
  end
end
