# The standard image-centered work show page, used for works by default, when
# we don't have a special purpose work show page.

class WorkImageShowComponent < ApplicationComponent
  delegate :construct_page_title, :current_user, to: :helpers

  attr_reader :work

  def initialize(work)
    @work = work
  end

  # Public members, ordered.
  # All the members to be displayed as thumbnails
  # underneath, and excluding, the hero image.
  #
  # When the first member in order was the representative, we eliminate it
  # from this list, cause it looks messy when there are only say two
  # images and one of them shows up twice!
  #
  # BUT when represnetative image is not first, we still repeat it here,
  # cause it's more confusing not to in that case.
  def member_list_for_display
    @member_list_display ||= begin
      members = work.members.includes(:leaf_representative)
      members = members.where(published: true) if current_user.nil?
      members = members.order(:position).to_a
      # If the representative image is the first item in the list, don't show it twice.
      members.delete_at(0) if members[0] == representative_member
      members
    end
  end

  def representative_is_in_member_list?
    unless defined?(@representative_in_member_list)
      @representative_in_member_list = member_list_for_display.include?(representative_member)
    end

    @representative_in_member_list
  end

  # Largely for accessibility. Sometimes we have alt_text in db we can use.
  #
  # In other cases all we can do at present is call it eg "Image 5"
  #
  # We have a zero-based index in member_list_for_display. Add one to make a
  # human 1-based index.
  #
  # If the member list does NOT include the represenentative index, that means
  # it starts at image _2_ not image 1, so add another one.
  def image_label_for_member_at_list_index(member, index)
    if member&.leaf_representative&.alt_text&.present?
      member.leaf_representative.alt_text
    else
      "Image #{index + 1 + (representative_is_in_member_list? ? 0 : 1)}"
    end
  end

  def transcription_texts
    @transcription_texts ||= ([representative_member] + member_list_for_display).compact.collect.with_index do |member, i|
      if member.kind_of?(Asset) && member.transcription.present?
        TextPage.new(
          member,
          image_number: i+1,
          text: member.transcription
        )
      end
    end.compact
  end

  def translation_texts
    @translation_texts ||= ([representative_member] + member_list_for_display).compact.collect.with_index do |member, i|
      if member.kind_of?(Asset) && member.english_translation.present?
        TextPage.new(
          member,
          image_number: i+1,
          text: member.english_translation
        )
      end
    end.compact
  end

  def has_transcription_or_translation?
    transcription_texts.present? || translation_texts.present?
  end


  # We don't want the leaf_representative, we want the direct representative member
  # to pass to MemberImageComponent. This will be an additional SQL fetch to
  # member_list_for_display, but a small targetted one-result one.
  def representative_member
    # memoize with a value that could be nil....
    return @representative_member if defined?(@representative_member)

    @representative_member = work.representative
  end

  # A weird helper method to lset us conditionally sometimes wrap
  # the work description in TranslationTabsComponent, other times not.
  #
  #   <%= maybe_wrap_with_component(wrapping_component: WrappingComponent.new, should_wrap: boolean) do %>
  #      More content that may or may not be wrapped.
  #   <% end %>
  def maybe_wrap_with_component(wrapping_component:, should_wrap:)
    if should_wrap
      render wrapping_component do
        yield
      end
    else
      yield
    end
  end

  # just a little value class for the things we need to display an individual
  # asset-page's worth of transcription or translation text
  class TextPage
    attr_reader :asset, :image_number, :text

    def initialize(asset, image_number:, text:)
      @asset = asset
      @image_number = image_number
      @text = text
    end

    def friendlier_id
      asset.friendlier_id
    end

  end
end
