# frozen_string_literal: true

# The standard image-centered work show page, used for works by default, when
# we don't have a special purpose work show page.

class WorkImageShowComponent < ApplicationComponent
  delegate :construct_page_title, :current_user, to: :helpers

  DEFAULT_THUMBNAIL_NUMBER = 2.freeze

  attr_reader :work, :work_download_options

  def initialize(work, show_all_members: false)
    @work = work
    @show_all_members = show_all_members 


    # work download options are expensive, so we calculate them here so we can use them
    # in several places
    @work_download_options = WorkDownloadOptionsCreator.new(work).options
  end

  # Public members, ordered, to be displayed as thumbnails
  # underneath the hero/representative image -- excluding the hero if it's the
  # first item in ordered list, cause it looks messy to show it twice in a row,
  # especially when we only have 2 or especially one member!
  #
  # We need to provide accessible labels to actions for images in list,
  # and the best we can do is "Image 1", "Image 2", "Image 10" etc.
  #
  # What that label is depends on if we excluded the representative or not though.
  # So we return MemberForThumbnailDisplay objects that have both the "member"
  # (Work or Asset), AND it's accessible label eg "Image 5"
  #

  # We only want to show a maximum of DEFAULT_THUMBNAIL_NUMBER thumbnails to the user by default,
  # to speed up the page.
  # See https://github.com/sciencehistory/scihist_digicoll/issues/905
  # See https://github.com/sciencehistory/scihist_digicoll/issues/2491
  def member_list_for_display
    @member_list_for_display ||= begin
      members = ordered_viewable_members

      unless @show_all_members
        members = members.limit DEFAULT_THUMBNAIL_NUMBER
      end

      members = members.to_a

      # If the representative image is the first item in the list, don't show it twice.
      start_image_number = 1
      if members[0] == representative_member
        members.delete_at(0)
        start_image_number = 2
      end

      members.collect.with_index do |member, index|
        MemberForThumbnailDisplay.new(member: member, image_label: "Image #{start_image_number + index}")
      end
    end
  end

  # All DISPLAYABLE (to current user) members, in order, and
  # with proper pre-fetches.
  def ordered_viewable_members
    @ordered_viewable_members ||= work.ordered_viewable_members(current_user: current_user).
        where("role is null OR role != ?", PdfToPageImages::SOURCE_PDF_ROLE)
  end

  def viewable_members_count
    @viewable_members_count ||= ordered_viewable_members.count
  end

  def hidden_viewable_members_count
    @hidden_viewable_members_count ||= @show_all_members ? 0 : (viewable_members_count - DEFAULT_THUMBNAIL_NUMBER)
  end

  def more_members_to_show?
    more_members_to_show? ||= viewable_members_count > DEFAULT_THUMBNAIL_NUMBER && !@show_all_members
  end

  def transcription_texts
    @transcription_texts ||= Work::TextPage.compile(ordered_viewable_members, accessor: :transcription)
  end

  def translation_texts
    @translation_texts ||= Work::TextPage.compile(ordered_viewable_members, accessor: :english_translation)
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

    @representative_member = (work.representative.try(:role) != PdfToPageImages::SOURCE_PDF_ROLE) ?  work.representative : nil
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

  # Encapsulates a member (Asset or Work), and an `image_label` like
  # "Image 5" that we use as a "best we've got" accessible label for
  # acitons like "Download Image 5"
  class MemberForThumbnailDisplay
    attr_reader :member, :image_label

    def initialize(member:, image_label:)
      @member = member
      @image_label = image_label
    end
  end
end
