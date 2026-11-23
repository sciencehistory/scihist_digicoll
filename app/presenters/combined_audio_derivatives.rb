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

  # If an OH is fully public, we store it's derivatives in a public cacheable S3 bucket,
  # but if it's by-request only we need to store it in a private bucket and deliver temporary URLs.
  def m4a_audio_url
    file = work&.oral_history_content&.combined_audio_m4a
    return nil unless file

    if file.storage_key.to_sym == :restricted_combined_audio_derivatives
      file.url(public: false, expires_in: DOWNLOAD_URL_EXPIRES_IN)
    else
      file.url(public: true)
    end
  end

  def derivatives_up_to_date?
    !!work&.oral_history_content&.combined_audio_up_to_date?
  end

  def m4a_audio_download_filename
    parts = [
      DownloadFilenameHelper.first_three_words(work.title),
      work.friendlier_id
    ].collect(&:presence).compact
    Pathname.new(parts.join("_")).sub_ext('.m4a').to_s
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

  def display_m4a_audio_size
    ScihistDigicoll::Util.simple_bytes_to_human_string(work&.oral_history_content&.combined_audio_m4a&.size)
  end
end
