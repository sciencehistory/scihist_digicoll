class OhAudioWorkShowDecorator < Draper::Decorator
  delegate_all
  include Draper::LazyHelpers

  DOWNLOAD_URL_EXPIRES_IN = 2.days.to_i

  # This is called by works_controller#show.
  def view_template
    'works/oh_audio_work_show'
  end



  # Cache the total list of published members, in other methods we'll search
  # through this in-memory to get members for various spots on the page.
  def all_members
    @all_members ||= begin
      members = model.members.includes(:leaf_representative)
      members = members.where(published: true) if current_user.nil?
      members.order(:position).to_a
    end
  end

  # We don't want the leaf_representative, we want the direct representative member
  # to pass to MemberImagePresenter.
  def representative_member
    # memoize with a value that could be nil....
    return @representative_member if defined?(@representative_member)

    @representative_member = all_members.find { |m| m.id == model.representative_id }
  end

  def audio_members
    @audio_members ||= all_members.select { |m| m.leaf_representative&.content_type&.start_with?("audio/") }
  end

  def file_list_members
    @file_list_members ||= all_members.select do |m|
       !m.leaf_representative&.content_type&.start_with?("audio/") && # exclude audio
       !m.role_portrait?  # exclude portrait role
     end
  end

  def has_ohms_transcript?
    model&.oral_history_content&.has_ohms_transcript?
  end

  def has_ohms_index?
    model&.oral_history_content&.has_ohms_index?
  end

  def combined_mp3_audio
    model&.oral_history_content&.combined_audio_mp3&.url(public:true)
  end

  def combined_mp3_audio_download_filename
    parts = [
      DownloadFilenameHelper.first_three_words(model.title),
      model.friendlier_id
    ].collect(&:presence).compact
    Pathname.new(parts.join("_")).sub_ext('.mp3').to_s
  end

  def combined_mp3_audio_download
    model&.oral_history_content&.combined_audio_mp3&.url(
      public: false,
      expires_in: DOWNLOAD_URL_EXPIRES_IN,
      response_content_type: 'audio/mpeg',
      response_content_disposition: ContentDisposition.format(
        disposition: 'attachment',
        filename: combined_mp3_audio_download_filename
      )
    )
  end

  def combined_mp3_audio_size
    ScihistDigicoll::Util.simple_bytes_to_human_string(model&.oral_history_content&.combined_audio_mp3&.size)
  end

  def combined_webm_audio
    model&.oral_history_content&.combined_audio_webm&.url(public:true)
  end

  def combined_audio_fingerprint
    model&.oral_history_content&.combined_audio_fingerprint
  end

  def derivatives_up_to_date?
    CombinedAudioDerivativeCreator.new(model).fingerprint == combined_audio_fingerprint
  end

  def portrait_asset
    unless defined?(@portrait_asset)
      @portrait_asset = all_members.find {|mem| mem.role_portrait? }&.leaf_representative
    end

    @portrait_asset
  end

  def interviewee_biographies
    model.oral_history_content&.interviewee_biographies || []
  end

  # An array of start times for each audio member.
  # The key is the member uuid (NOT the friendlier id)
  # The value is the offset in seconds into the combined audio.
  # The first value in the array, if there is one,
  # should ALWAYS be zero.
  def start_times
    @start_times ||= begin
      metadata = model&.oral_history_content&.combined_audio_component_metadata
      metadata ? metadata['start_times'].to_h : {}
    end
  end

  # The start time or audio offset for a particular audio asset,
  # relative to the entire oral history interview (the work as a whole).
  # We're rounding to the nearest tenth of a second; easier to read.
  # Returns nil if there is no start time for this asset, or for any assets.
  def start_time_for(audio_asset)
    start_times[audio_asset.id]
  end

end
