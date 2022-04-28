# just a wrapper around a Work, for use with oral histories with "combined audio derivatives",
# just some logic around them, extracted to a helper object so it can be re-used in more than one place.
#
# For legacy reasons this isn't unit-tested, but probably could/should be!
class CombinedAudioDerivatives
  DOWNLOAD_URL_EXPIRES_IN = 2.days.to_i

  attr_reader :work

  def initialize(work)
    @work = work
  end

  # REMOVE_AFTER_MP3_TO_M4A_MIGRATION
  def mp3_audio_url
    work&.oral_history_content&.combined_audio_mp3&.url(public:true)
  end

  # REMOVE_AFTER_MP3_TO_M4A_MIGRATION
  def webm_audio_url
    work&.oral_history_content&.combined_audio_webm&.url(public:true)
  end

  def m4a_audio_url
    work&.oral_history_content&.combined_audio_m4a&.url(public:true)
  end

  def audio_fingerprint
    work&.oral_history_content&.combined_audio_fingerprint
  end

  def derivatives_up_to_date?
    CombinedAudioDerivativeCreator.new(work).fingerprint == audio_fingerprint
  end


  # REMOVE_AFTER_MP3_TO_M4A_MIGRATION
  def mp3_audio_download_filename
    parts = [
      DownloadFilenameHelper.first_three_words(work.title),
      work.friendlier_id
    ].collect(&:presence).compact
    Pathname.new(parts.join("_")).sub_ext('.mp3').to_s
  end


  def m4a_audio_download_filename
    parts = [
      DownloadFilenameHelper.first_three_words(work.title),
      work.friendlier_id
    ].collect(&:presence).compact
    Pathname.new(parts.join("_")).sub_ext('.m4a').to_s
  end


  # REMOVE_AFTER_MP3_TO_M4A_MIGRATION
  def mp3_audio_download_url
    work&.oral_history_content&.combined_audio_mp3&.url(
      public: false,
      expires_in: DOWNLOAD_URL_EXPIRES_IN,
      response_content_type: 'audio/mpeg',
      response_content_disposition: ContentDisposition.format(
        disposition: 'attachment',
        filename: mp3_audio_download_filename
      )
    )
  end

  def m4a_audio_download_url
    work&.oral_history_content&.combined_audio_m4a&.url(
      public: false,
      expires_in: DOWNLOAD_URL_EXPIRES_IN,
      response_content_type: 'audio/mpeg',
      response_content_disposition: ContentDisposition.format(
        disposition: 'attachment',
        filename: m4a_audio_download_filename
      )
    )
  end


  # REMOVE_AFTER_MP3_TO_M4A_MIGRATION
  def display_mp3_audio_size
    ScihistDigicoll::Util.simple_bytes_to_human_string(work&.oral_history_content&.combined_audio_mp3&.size)
  end

  def display_m4a_audio_size
    ScihistDigicoll::Util.simple_bytes_to_human_string(work&.oral_history_content&.combined_audio_m4a&.size)
  end
end
