class AudioWorkShowDecorator < WorkShowDecorator

  def self.has_audio_members?(some_work)
    some_work.members.
      where(published: true).to_a.
      any? { | x| self.is_audio?(x) }
  end

  def audio_members
    @ordered_public_members ||= begin
      ordered_public_members.select { | x| self.class.is_audio?(x) }
    end
  end

  # Not including the representative IF the representative is the first item in the
  # list, because no reason to duplicate it right after the representative.
  def non_audio_member_list_for_display
    result = ordered_public_members.select { | x| !self.class.is_audio?(x) }
    result.delete_at(0) if result[0] == representative_member
    result
  end

  private

  # Public members, ordered.
  def ordered_public_members
    @ordered_public_members ||= begin
      members = model.members.
        with_representative_derivatives.
        where(published: true).
        order(:position).
        to_a
      members
    end
  end

  def self.is_audio?(member)
    member.kind_of?(Kithe::Asset) &&
      member.file &&
      member.content_type.start_with?("audio/") &&
      member.derivatives.present?
  end

end
