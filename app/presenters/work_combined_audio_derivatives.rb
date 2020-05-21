# Shows UI related to the combined audio derivatives of an
# oral history work on the work admin page (on the Oral History tab).
#
# app/presenters/work_combined_audio_derivatives.rb
class WorkCombinedAudioDerivatives < ViewModel
  valid_model_type_names "Work"

  delegate :genre, :title, :additional_title, :parent, :source, :date_of_work, :published?

  def display
    render 'admin/works/combined_audio_derivatives', model: model, view: self
  end

  def work_published_audio_members_available?
    @work_published_audio_members_count ||= CombinedAudioDerivativeCreator.new(model).available_members?
  end

  def work_available_members_count
    @work_available_members_count ||= CombinedAudioDerivativeCreator.new(model).available_members_count
  end

  def combined_mp3_audio
    return nil unless model.genre.present?
    return nil unless model.genre.include?('Oral histories')
    return nil unless work_published_audio_members_available?
    oh_content = model.oral_history_content!
    oh_content.combined_audio_mp3&.url(public:true)
  end

  def combined_webm_audio
    return nil unless model.genre.present?
    return nil unless model.genre.include?('Oral histories')
    return nil unless work_published_audio_members_available?
    oh_content = model.oral_history_content!
    oh_content.combined_audio_webm&.url(public:true)
  end

  def combined_audio_fingerprint
    return nil unless model.genre.present?
    return nil unless model.genre.include?('Oral histories')
    model.oral_history_content!.combined_audio_fingerprint
  end

  def derivatives_up_to_date?
    CombinedAudioDerivativeCreator.new(model).fingerprint == combined_audio_fingerprint
  end

end
